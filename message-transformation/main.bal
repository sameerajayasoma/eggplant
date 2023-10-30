import ballerina/http;
import ballerina/log;

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

configurable int port = 8290;
configurable string hospitalServiceUrl = "http://localhost:9090";

final http:Client hospitalServiceEP = check new (hospitalServiceUrl);

service /healthcare on new http:Listener(port) {

    resource function post categories/[string category]/reserve(HealthcareReservation payload)
            returns ReservationResponse|http:NotFound|http:InternalServerError {

        final HealthcareReservation & readonly reservation = payload.cloneReadOnly();

        worker TransformToHospitalReservation {
            HospitalReservation hospitalRes = transform(reservation);
            hospitalRes -> PostHospitalReservation;
        }

        worker PostHospitalReservation returns error? {
            HospitalReservation hospitalRes = <- TransformToHospitalReservation;
            string hospitalId = reservation.hospitalId;
            ReservationResponse reservationResp = check hospitalServiceEP->/[hospitalId]/categories/[category]/reserve.post(hospitalRes);
            
            [hospitalRes, reservationResp] -> LogReservationResponse;
            reservationResp -> function;
        }

        worker LogReservationResponse returns error? {
            [HospitalReservation, ReservationResponse] [hospitalRes, reservationResp] = check <- PostHospitalReservation;
            log:printDebug("Reservation request successful", name = hospitalRes.patient.name,
                            appointmentNumber = reservationResp.appointmentNumber);
        }

        // TODO The following error handling logic is available in the original Ballerina sample. 
        // We need to figure out a way to handle this using workers.
        ReservationResponse|error reservationResp = <- PostHospitalReservation;
        if reservationResp is http:ClientRequestError {
            return <http:NotFound>{body: "Unknown hospital, doctor or category"};
        } else if reservationResp is error {
            log:printError("Error occurred while reserving", 'error = reservationResp);
            return <http:InternalServerError>{body: reservationResp.message()};
        } else {
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
