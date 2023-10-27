import ballerina/http;
import ballerina/log;

configurable string hospitalServicesBackend = "http://localhost:9090";
configurable string paymentBackend = "http://localhost:9090/healthcare/payments";

type Patient record {|
    string name;
    string dob;
    string ssn;
    string address;
    string phone;
    string email;
|};

type ReservationRequest record {|
    record {|
        *Patient;
        string cardNo;
    |} patient;
    string doctor;
    string hospital_id;
    string hospital;
    string appointment_date;
|};

type AppointmentRequest record {|
    Patient patient;
    string doctor;
    string hospital;
    string appointment_date;
|};

type Doctor record {|
    readonly string name;
    string hospital;
    string category;
    string availability;
    decimal fee;
|};

type Appointment record {|
    int appointmentNumber;
    Doctor doctor;
    Patient patient;
    string hospital;
    boolean confirmed;
    string appointmentDate;
|};

type ChannelingFee record {|
    string patientName;
    string doctorName;
    string actualFee;
|};

type PaymentSettlement record {|
    int appointmentNumber;
    Doctor doctor;
    Patient patient;
    decimal fee;
    boolean confirmed;
    string card_number;
|};

final http:Client hospitalServicesEP = check initializeHttpClient(hospitalServicesBackend);
final http:Client paymentEP = check initializeHttpClient(paymentBackend);


function initializeHttpClient(string url) returns http:Client|error => new (url);

service /healthcare on new http:Listener(9095) {

    resource function post categories/[string category]/reserve(ReservationRequest payload, http:Caller caller) returns error? {
        check runIntegration(category, payload, caller);
    }
}

function runIntegration(string category, ReservationRequest payload, http:Caller caller) returns error? {

    // @foo:LogMediator
    worker LogHospitalDetails {
        ReservationRequest requestPayload = <- function;
        log:printInfo("ReservationRequest123", payload = requestPayload);
    }

    // @foo:DataMapper
    worker CreateAppoinmentPayload {
        ReservationRequest requestPayload = <- function;
        AppointmentRequest appoinmentReq = appoinmentPayloadMapper(requestPayload);
        appoinmentReq -> CreateAppoinment;
    }

    // @foo:HttpPostMediator
    worker CreateAppoinment returns error? {
        // [JBUG] Multiple Receive actions are not yet supported
        // AppointmentRequest appoinmentReq = <- {function, CreateAppoinmentPayload};

        string doctorCategory = <- function;
        ReservationRequest requestPayload = <- function;
        AppointmentRequest appoinmentReq = <- CreateAppoinmentPayload;

        Appointment|error appt = hospitalServicesEP->/[requestPayload.hospital_id]/categories/[doctorCategory]/reserve.post(appoinmentReq);
        if appt is error {
            // [JBUG]worker send statement position not supported yet, must be a top level statement in a worker(BCE2073)
            // appt -> HandleResereAppoinmentError;
            log:printError("Error occurred when making an appoinment", 'error = appt);
            // TODO: Use caller to respond with error
            return appt;
        }

        appt -> LogAppoinment;
        appt -> GetAppoinmentFee;
    }

    // worker HandleResereAppoinmentError {
    //     error err = <- CreateAppoinment;
    //     log:printError("Error occurred", 'error = err);
    // }

    // @foo:LogMediator
    worker LogAppoinment returns error? {
        Appointment appoinment = check <- CreateAppoinment;
        log:printInfo("Appoinment", payload = appoinment);
    }

    // @foo:HttpGetMediator
    worker GetAppoinmentFee returns error? {
        ReservationRequest reservationReq = <- function;
        string hospitalId = reservationReq.hospital_id;

        Appointment appoinment = check <- CreateAppoinment;
        int apptNumber = appoinment.appointmentNumber;

        ChannelingFee|error fee = hospitalServicesEP->/[hospitalId]/categories/appointments/[apptNumber]/fee;
        if fee is error {
            log:printError("Error occurred when getting appoinment fee", 'error = fee);
            return fee;
        }
        fee -> LogChannelingFee;
        reservationReq -> CreatePaymentRequest;
        appoinment -> CreatePaymentRequest;
        fee -> CreatePaymentRequest;
    }

    // @foo:LogMediator
    worker LogChannelingFee returns error? {
        ChannelingFee fee = check <- GetAppoinmentFee;
        log:printInfo("ChannelingFee", payload = fee);
    }

    // @foo:DataMapper
    worker CreatePaymentRequest returns error? {
        ReservationRequest reservationReq = check <- GetAppoinmentFee;
        Appointment appointment = check <- GetAppoinmentFee;
        ChannelingFee channelingFee = check <- GetAppoinmentFee;
        PaymentSettlement paymentSettlementReq = check paymentRequestPayloadMapper(reservationReq, appointment, channelingFee);
        paymentSettlementReq -> MakePayment;
    }

    // @foo:HttpPostMediator
    worker MakePayment returns error? {
        PaymentSettlement paymentSettlementReq = check <- CreatePaymentRequest;
        json|error response = paymentEP->/.post(paymentSettlementReq);
        if response is error {
            log:printError("Error occurred when making payment", 'error = response);
            return response;
        } else {
            error? callerError = caller->respond(response);
            if callerError is error {
                log:printError("Error occurred when responding to the client", 'error = callerError);
                return callerError;
            }
        }
        response -> LogPaymentResponse;
    }

    // @foo:LogMediator
    worker LogPaymentResponse returns error? {
        json response = check <- MakePayment;
        log:printInfo("PaymentResponse", payload = response);
    }

    payload -> LogHospitalDetails;
    payload -> CreateAppoinmentPayload;
    category -> CreateAppoinment;
    payload -> CreateAppoinment;
    payload -> GetAppoinmentFee;

    // Need to figure how to wait for the integration to complete
    error? result = wait LogPaymentResponse;
    if result is error {
        log:printError("Error occurred ", 'error = result);
        return result;
    }   
}

isolated function appoinmentPayloadMapper(ReservationRequest reservationRequest) returns AppointmentRequest => {
    patient: {
        name: reservationRequest.patient.name,
        dob: reservationRequest.patient.dob,
        ssn: reservationRequest.patient.ssn,
        address: reservationRequest.patient.address,
        phone: reservationRequest.patient.phone,
        email: reservationRequest.patient.email
    },
    doctor: reservationRequest.doctor,
    hospital: reservationRequest.hospital,
    appointment_date: reservationRequest.appointment_date
};

isolated function paymentRequestPayloadMapper(ReservationRequest reservationReq, Appointment appointment, ChannelingFee channelingFee) returns PaymentSettlement|error => {
    appointmentNumber: appointment.appointmentNumber,
    doctor: appointment.doctor,
    patient: appointment.patient,
    fee: check decimal:fromString(channelingFee.actualFee),
    confirmed: false,
    card_number: reservationReq.patient.cardNo
};
