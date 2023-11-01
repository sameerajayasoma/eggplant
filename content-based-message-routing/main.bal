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

service /healthcare on new http:Listener(port) {

    isolated resource function post categories/[string category]/reserve(ReservationRequest payload)
            returns ReservationResponse|http:NotFound|http:InternalServerError {

        final var reservationReq = payload.cloneReadOnly();

        worker LogReservationRequestDetails {
            log:printInfo("Routing reservation request",
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
            boolean isGrandOak = false;
            boolean isClemency = false;
            boolean isPineValley = false;

            match hospitalId {
                GRAND_OAK => {
                    isGrandOak = true;
                }
                CLEMENCY => {
                    isClemency = true;
                }
                PINE_VALLEY => {
                    isPineValley = true;
                }
            }

            // Trigger all the workers in parallel
            [isGrandOak, isClemency, isPineValley, reservation] -> PostRequestToGrandOakEp;
            [isGrandOak, isClemency, isPineValley, reservation] -> PostRequestToClemencyEP;
            [isGrandOak, isClemency, isPineValley, reservation] -> PostRequestToPineValleyEP;
        }

        worker PostRequestToGrandOakEp returns error? {
            [boolean, boolean, boolean, Reservation] [isGrandOak, _, _, reservation] = <- RouteToEndpointBasedOnHospitalId;
            ReservationResponse? resp = ();
            if isGrandOak {
                resp = check grandOakEP->/[category]/reserve.post(reservation);
            }
            resp -> CollectResponse;
        }

        worker PostRequestToClemencyEP returns error? {
            [boolean, boolean, boolean, Reservation] [_, isClemency, _, reservation] = <- RouteToEndpointBasedOnHospitalId;
            ReservationResponse? resp = ();
            if isClemency {
                resp = check clemencyEP->/[category]/reserve.post(reservation);
            }
            resp -> CollectResponse;
        }

        worker PostRequestToPineValleyEP returns error? {
            [boolean, boolean, boolean, Reservation] [_, _, isPineValley, reservation] = <- RouteToEndpointBasedOnHospitalId;
            ReservationResponse? resp = ();
            if isPineValley {
                resp = check pineValleyEP->/[category]/reserve.post(reservation);
            }
            resp -> CollectResponse;
        }

        worker CollectResponse returns error? {
            ReservationResponse? grandOakResp = check <- PostRequestToGrandOakEp;
            ReservationResponse? clemencyResp = check <- PostRequestToClemencyEP;
            ReservationResponse? PineValleyResp = check <- PostRequestToPineValleyEP;
            ReservationResponse resp = grandOakResp !is () ? grandOakResp : clemencyResp !is () ? clemencyResp : <ReservationResponse>PineValleyResp;
            resp -> function;
        }

        // TODO The following error handling logic is available in the original Ballerina sample. 
        // We need to figure out a way to handle this using workers.
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
