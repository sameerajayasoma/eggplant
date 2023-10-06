import ballerina/http;
import ballerina/io;
import ballerina/log;

import sameera/dataflow as df;

configurable int port = 8290;
configurable string hospitalServicesBackend = "http://localhost:9090";
configurable string paymentBackend = "http://localhost:9090/healthcare/payments";

final http:Client hospitalServicesEP = check initializeHttpClient(hospitalServicesBackend);
final http:Client paymentEP = check initializeHttpClient(paymentBackend);

function initializeHttpClient(string url) returns http:Client|error => new (url);

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

type ReservationStatus record {|
    int appointmentNo;
    string doctorName;
    string patient;
    decimal actualFee;
    int discount;
    decimal discounted;
    string paymentID;
    string status;
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

service /healthcare on new http:Listener(port) {
    private final df:TargetNode reservationSequence;

    function init() returns error? {
        self.reservationSequence = check initReservationSequence();
    }

    resource function post categories/[string category]/reserve(ReservationRequest payload, http:Caller caller) returns error? {
        df:MessageContext msgCtx = new ();
        msgCtx.addSystemVariable("http_caller", caller);
        msgCtx.addVariable("var_http_path_category", category);

        error? err = self.reservationSequence.send(payload, msgCtx);
        if (err is error) {
            log:printError("Error occurred while sending message to postNumberSequence", 'error = err);
            return err;
        }
    }
}

function initReservationSequence() returns df:TargetNode|error {
    df:VariableSetNode patientVarSet = new ("PatientVarSet", "var_patient", msg => msg is ReservationRequest ? msg.patient : msg);

    df:VariableSetNode patientCardNoVarSet = new ("PatientCardNoVarSet", "var_patient_card_no", msg => msg is ReservationRequest ? msg.patient.cardNo : msg);
    patientVarSet.targetEdge(patientCardNoVarSet);

    df:VariableSetNode doctorVarSet = new ("DoctorVarSet", "var_doctor", msg => msg is ReservationRequest ? msg.doctor : msg);
    patientCardNoVarSet.targetEdge(doctorVarSet);

    df:VariableSetNode hospitalVarSet = new ("HospitalVarSet", "var_hospital", msg => msg is ReservationRequest ? msg.hospital : msg);
    doctorVarSet.targetEdge(hospitalVarSet);

    df:VariableSetNode hospitalIdVarSet = new ("HospitalIdVarSet", "var_hospital_id", msg => msg is ReservationRequest ? msg.hospital_id : msg);
    hospitalVarSet.targetEdge(hospitalIdVarSet);

    df:LoggerNode hospitalIdVarLogger = new ("HospitalIdVarLogger", "INFO", false, [{key: "var_hospital_id", value: {kind: df:VALUE_KIND_VARIABLE, value: "var_hospital_id"}}]);
    hospitalIdVarSet.targetEdge(hospitalIdVarLogger);

    df:VariableSetNode apptDateVarSet = new ("AppointmentDateVarSet", "var_appt_date", msg => msg is ReservationRequest ? msg.appointment_date : msg);
    hospitalIdVarLogger.targetEdge(apptDateVarSet);

    df:LoggerNode debugLoggerInitReservation = new ("DebugLoggerInitReservation", "INFO");
    apptDateVarSet.targetEdge(debugLoggerInitReservation);

    // [hospital_id]/categories/[category]/reserve
    readonly & df:Value[] reserveResourcePathSegments = [
        {kind: df:VALUE_KIND_VARIABLE, value: "var_hospital_id"},
        {kind: df:VALUE_KIND_LITERAL, value: "categories"},
        {kind: df:VALUE_KIND_VARIABLE, value: "var_http_path_category"},
        {kind: df:VALUE_KIND_LITERAL, value: "reserve"}
    ];
    df:HttpResourcePathNode apptSvcResourcePathSet = new ("ReserveResourcePath", "var_appt_svc_resource_path", reserveResourcePathSegments);
    debugLoggerInitReservation.targetEdge(apptSvcResourcePathSet);

    // Create the POST payload using a data mapper
    df:DataMapperNode createApptPayaload = new ("ReserveAppoinmentPayaload", appoinmentPayloadMapperWrapper);
    apptSvcResourcePathSet.targetEdge(createApptPayaload);

    df:HttpPostClientNode apptSvcPostRequest = new ("ReserveAppoinmentRequest", hospitalServicesEP,
        {kind: df:VALUE_KIND_VARIABLE, value: "var_appt_svc_resource_path"}
    );
    createApptPayaload.targetEdge(apptSvcPostRequest);

    df:VariableSetNode apptDoctorVarSet = new ("ApptDoctorVarSet", "var_appt_doctor", extractApptDoctor);
    apptSvcPostRequest.targetEdge(apptDoctorVarSet);

    df:HttpErrorHandlerNode apptSvcErrorHandler = new ("ApptSvcErrorHandler");
    apptSvcPostRequest.targetErrorHandlerEdge(apptSvcErrorHandler);

    df:VariableSetNode apptPatientVarSet = new ("ApptPatientVarSet", "var_appt_patient", extractApptPatient);
    apptDoctorVarSet.targetEdge(apptPatientVarSet);

    df:VariableSetNode apptNumberVarSet = new ("AppointmentNumberVarSet", "var_appt_number", extractApptNumber);
    apptPatientVarSet.targetEdge(apptNumberVarSet);

    // [hospital_id]/categories/appointments/[appointmentNumber]/fee
    readonly & df:Value[] feeResourcePathSegments = [
        {kind: df:VALUE_KIND_VARIABLE, value: "var_hospital_id"},
        {kind: df:VALUE_KIND_LITERAL, value: "categories"},
        {kind: df:VALUE_KIND_LITERAL, value: "appointments"},
        {kind: df:VALUE_KIND_VARIABLE, value: "var_appt_number"},
        {kind: df:VALUE_KIND_LITERAL, value: "fee"}
    ];
    df:HttpResourcePathNode feeSvcResourcePathSet = new ("FeeResourcePath", "var_fee_resource_path", feeResourcePathSegments);
    apptNumberVarSet.targetEdge(feeSvcResourcePathSet);

    df:HttpGetClientNode feeSvcGetRequest = new ("FeeServiceRequest", hospitalServicesEP,
        {kind: df:VALUE_KIND_VARIABLE, value: "var_fee_resource_path"}
    );
    feeSvcResourcePathSet.targetEdge(feeSvcGetRequest);

    df:VariableSetNode actualFeeVarSet = new ("ActualFeeVarSet", "var_actual_fee", extractFee);
    feeSvcGetRequest.targetEdge(actualFeeVarSet);

    df:HttpErrorHandlerNode feeSvcErrorHandler = new ("FeeSvcErrorHandler");
    feeSvcGetRequest.targetErrorHandlerEdge(feeSvcErrorHandler);

    df:DataMapperNode paymentRequestPayaload = new ("PaymentRequestPayaload", paymentRequestPayloadMapperWrapper);
    actualFeeVarSet.targetEdge(paymentRequestPayaload);

    df:HttpPostClientNode paymentSvcPostRequest = new ("PaymentRequest", paymentEP, {kind: df:VALUE_KIND_LITERAL, value: ""});
    paymentRequestPayaload.targetEdge(paymentSvcPostRequest);

    df:LoggerNode logResponse = new ("LogResponse", "INFO", false, [{key: "msg", value: {kind: df:VALUE_KIND_LITERAL, value: "Appointment reservation successful"}}]);
    paymentSvcPostRequest.targetEdge(logResponse);

    df:HttpErrorHandlerNode paymentSvcErrorHandler = new ("PaymentSvcErrorHandler");
    paymentSvcPostRequest.targetErrorHandlerEdge(paymentSvcErrorHandler);

    df:HttpCallerNode respondToCaller = new ("RespondToCaller");
    logResponse.targetEdge(respondToCaller);

    df:Graph diGraph = new ();
    patientVarSet.serialize(diGraph);
    io:println(diGraph.toString());
    return patientVarSet;
}

isolated function appoinmentPayloadMapperWrapper(anydata message, map<readonly & anydata> variables) returns anydata|error {
    return appoinmentPayloadMapper(check message.ensureType(), check variables.cloneWithType());
}

isolated function appoinmentPayloadMapper(ReservationRequest reservationRequest, record {} vars) returns AppointmentRequest => {
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

isolated function paymentRequestPayloadMapperWrapper(anydata message, map<readonly & anydata> variables) returns anydata|error {
    return paymentRequestPayloadMapper(check message.ensureType(), check variables.cloneWithType());
}

isolated function paymentRequestPayloadMapper(anydata message,
        record {
            int var_appt_number;
            Doctor var_appt_doctor;
            Patient var_appt_patient;
            decimal var_actual_fee;
            boolean confirmed = false;
            string var_patient_card_no;
        } variables) returns PaymentSettlement => {
    appointmentNumber: variables.var_appt_number,
    doctor: variables.var_appt_doctor,
    patient: variables.var_appt_patient,
    fee: variables.var_actual_fee,
    confirmed: variables.confirmed,
    card_number: variables.var_patient_card_no
};

isolated function extractApptNumber(anydata message) returns anydata|error {
    Appointment appointment = check message.cloneWithType();
    return appointment.appointmentNumber;
}

isolated function extractFee(anydata message) returns anydata|error {
    ChannelingFee channelingFee = check message.cloneWithType();
    return decimal:fromString(channelingFee.actualFee);
}

isolated function extractApptDoctor(anydata message) returns anydata|error {
    Appointment appointment = check message.cloneWithType();
    return appointment.doctor;
}

isolated function extractApptPatient(anydata message) returns anydata|error {
    Appointment appointment = check message.cloneWithType();
    return appointment.patient;
}
