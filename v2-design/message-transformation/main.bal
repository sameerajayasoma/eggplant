import ballerina/http;
import ballerina/log;

import samjs/eggplant as _;

type HealthcareReservation record {|
    string firstName;
    string lastName;
    string dob;
    int[3] ssn;
    string address;
    string phone;
    string email;
    string doctor;
    string hospitalId;
    string hospital;
    string cardNo;
    string appointmentDate;
|};

type Patient record {|
    string name;
    string dob;
    string ssn;
    string address;
    string phone;
    string email;
|};

type HospitalReservation record {|
    Patient patient;
    string doctor;
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

// public type Cloneable readonly|xml|Cloneable[]|map<Cloneable>|table<map<Cloneable>>;
// type Foo record {| Cloneable payload; map<Cloneable> vars; |};
// // Error: Ambiguous type
// Foo foo = {payload:{"a":1, "b":2}, vars:{"a":1, "b":2}};

type Message record {|
    anydata payload;
    map<anydata> vars = {};
|};

type HttpRequest record {|
    string rawPath = "";
    string method = "";
    string httpVersion = "";
    string userAgent = "";
    string extraPathInfo = "";
    map<string> headers;
    map<string[]> queryParams;
    map<string> pathParams;
|};

type HttpMessage record {|
    *Message;
    // I tried using HealthcareReservation as the payload type, 
    //  but it doesn't work. It doesn't allow me to modify or update the payload to a different type later.
    anydata payload;
    HttpRequest httpRequest;
|};

configurable string hospitalServiceUrl = "http://localhost:9090";

final http:Client hospitalServiceEP = check new (hospitalServiceUrl);

service /healthcare on new http:Listener(8290) {

    resource function post categories/[string speciality]/reserve(HealthcareReservation payload, http:Request req)
            returns ReservationResponse|http:NotFound|http:InternalServerError {

        HttpMessage requestMessage = {
            payload,
            httpRequest: {
                rawPath: req.rawPath,
                method: req.method,
                httpVersion: req.httpVersion,
                userAgent: req.userAgent,
                extraPathInfo: req.extraPathInfo,
                headers: getHttpHeaders(req),
                queryParams: req.getQueryParams(),
                pathParams: {speciality}
            }
        };

        worker StartNode returns error? {
            HttpMessage message = <- function;
            message -> TransformNode;
        }

        // TransformToHospitalReservation
        worker TransformNode returns error?{
            HttpMessage message = <- StartNode;
            
            // We can ask the user to provide the type of the input and output.
            HealthcareReservation reservation = check message.payload.ensureType();
            HospitalReservation hospitalRes = transform(reservation);

            // Declaring a new variable called "hospitalRes".
            message.vars["hospitalRes"] = hospitalRes;
            message -> HttpPostNode;
        }

        // PostHospitalReservation
        worker HttpPostNode returns error? {
            HttpMessage message = check <- TransformNode;

            // How do we know the type of the variable "hospitalRes" here?
            HospitalReservation hospitalRes = check message.vars["hospitalRes"].ensureType();
            HealthcareReservation reservation = check message.payload.ensureType();

            string hospitalId = reservation.hospitalId;
            string docSpeciality = message.httpRequest.pathParams.get("speciality");
            ReservationResponse reservationResp = check hospitalServiceEP->/[hospitalId]/categories/[docSpeciality]/reserve.post(hospitalRes);

            // Declaring a new variable called "reservationResp".
            message.vars["reservationResp"] = reservationResp;

            message -> LogNode;
            message -> ResponseNode;
        }

        // LogReservationResponse
        worker LogNode returns error? {
            HttpMessage message = check <- HttpPostNode;

            HospitalReservation hospitalRes = check message.vars["hospitalRes"].ensureType();
            ReservationResponse reservationResp = check message.vars["reservationResp"].ensureType();

            log:printInfo("Reservation request successful", name = hospitalRes.patient.name,
                            appointmentNumber = reservationResp.appointmentNumber);
        }

        worker ResponseNode returns error? {
            HttpMessage message = check <- HttpPostNode;

            ReservationResponse reservationResp = check message.vars["reservationResp"].ensureType();
            message.payload = reservationResp;
            message -> function;
        }

        requestMessage -> StartNode;

        HttpMessage|error responseMessage = <- ResponseNode;

        if responseMessage is http:ClientRequestError {
            return <http:NotFound>{body: "Unknown hospital, doctor or category"};
        } else if responseMessage is error {
            log:printError("Error occurred while reserving", 'error = responseMessage);
            return <http:InternalServerError>{body: responseMessage.message()};
        } else {
            // I used `checkpanic` to make things simple for now.
            ReservationResponse reservationResp = checkpanic responseMessage.payload.ensureType();
            return reservationResp;
        }
    }
}

function transform(HealthcareReservation reservation) returns HospitalReservation =>
    let var ssn = reservation.ssn in {
        patient: {
            name: reservation.firstName + " " + reservation.lastName,
            dob: reservation.dob,
            ssn: string `${ssn[0]}-${ssn[1]}-${ssn[2]}`,
            address: reservation.address,
            phone: reservation.phone,
            email: reservation.email
        },
        doctor: reservation.doctor,
        hospital: reservation.hospital,
        appointment_date: reservation.appointmentDate
    };

function getHttpHeaders(http:Request req) returns map<string> {
    map<string> headers = {};
    foreach var key in req.getHeaderNames() {
        // I used `checkpanic` to make things simple for now.
        headers[key] = checkpanic req.getHeader(key);
    }
    return headers;
}
