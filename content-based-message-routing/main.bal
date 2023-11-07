import ballerina/http;
import ballerina/log;

import samjs/eggplant as _;

configurable int port = 8290;

final http:Client grandOakEP = check initializeHttpClient("http://localhost:9090/grandoak/categories");
final http:Client clemencyEP = check initializeHttpClient("http://localhost:9090/clemency/categories");
final http:Client pineValleyEP = check initializeHttpClient("http://localhost:9090/pinevalley/categories");

function initializeHttpClient(string url) returns http:Client|error => new (url);

enum HospitalId {
    GRAND_OAK = "grandoak",
    CLEMENCY = "clemency",
    PINE_VALLEY = "pinevalley"
};

type Patient record {|
    string name;
    string dob;
    string ssn;
    string address;
    string phone;
    string email;
|};

type Reservation record {|
    Patient patient;
    string doctor;
    string hospital;
    string appointment_date;
|};

type ReservationRequest record {|
    Patient patient;
    string doctor;
    HospitalId hospital_id;
    string hospital;
    string appointment_date;
|};

type Doctor record {|
    string name;
    string hospital;
    string category;
    string availability;
    float fee;
|};

type ReservationResponse record {|
    int appointmentNumber;
    Doctor doctor;
    Patient patient;
    string hospital;
    boolean confirmed;
    string appointmentDate;
|};

type NoMessageError distinct error;

service /healthcare on new http:Listener(port) {

    resource function post categories/[string category]/reserve(ReservationRequest payload)
            returns ReservationResponse|http:NotFound|http:InternalServerError {
        final var reservationReq = payload.cloneReadOnly();

        worker LogReservationRequestDetails {
            log:printInfo("Reservation request received",
                        hospital_id = reservationReq.hospital_id,
                        patient = reservationReq.patient.name,
                        doctor = reservationReq.doctor);
        }

        worker CreateOutgoingPayload {
            Reservation reservation = transformReservationRequest(reservationReq);
            reservation -> RouteToEndpointBasedOnHospitalId;
        }

        worker RouteToEndpointBasedOnHospitalId {
            Reservation reservation = <- CreateOutgoingPayload;
            string hospitalId = reservationReq.hospital_id;

            Reservation|NoMessageError grandOakSend = error("");
            Reservation|NoMessageError clemencySend = error("");
            Reservation|NoMessageError pineValleySend = error("");

            match hospitalId {
                GRAND_OAK => {
                    grandOakSend = reservation;
                }
                CLEMENCY => {
                    clemencySend = reservation;
                }
                PINE_VALLEY => {
                    pineValleySend = reservation;
                }
            }

            grandOakSend -> PostRequestToGrandOakEp;
            clemencySend -> PostRequestToClemencyEP;
            pineValleySend -> PostRequestToPineValleyEP;
        }

        worker PostRequestToGrandOakEp returns ReservationResponse|error {
            Reservation reservation = check <- RouteToEndpointBasedOnHospitalId;
            log:printInfo("Sending reservation request to Grand Oak");
            return grandOakEP->/[category]/reserve.post(reservation);
        }

        worker PostRequestToClemencyEP returns ReservationResponse|error {
            Reservation reservation = check <- RouteToEndpointBasedOnHospitalId;
            log:printInfo("Sending reservation request to Clemency");
            return clemencyEP->/[category]/reserve.post(reservation);
        }

        worker PostRequestToPineValleyEP returns ReservationResponse|error {
            Reservation reservation = check <- RouteToEndpointBasedOnHospitalId;
            log:printInfo("Sending reservation request to Pine Valley");
            return pineValleyEP->/[category]/reserve.post(reservation);
        }

        worker CollectResponse returns error? {
            ReservationResponse|error resp = wait PostRequestToGrandOakEp | PostRequestToClemencyEP | PostRequestToPineValleyEP;
            resp -> function;
        }

        ReservationResponse|error resp = <- CollectResponse;
        if resp is http:ClientRequestError {
            return <http:NotFound>{body: "Unknown hospital, doctor or category"};
        } else if resp is error {
            log:printError("Error occurred while reserving", 'error = resp);
            return <http:InternalServerError>{body: resp.message()};
        } else {
            return resp;
        }
    }
}

isolated function transformReservationRequest(ReservationRequest reservationRequest) returns Reservation => {
    patient: reservationRequest.patient,
    appointment_date: reservationRequest.appointment_date,
    doctor: reservationRequest.doctor,
    hospital: reservationRequest.hospital
};
