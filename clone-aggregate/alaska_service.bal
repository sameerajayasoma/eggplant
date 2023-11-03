import ballerina/http;

type AlaskaAirFareRequest record {|
    string sCode;
    string dCode;
    int nPassengers;
|};

type AlaskaAirfareResponse record {|
    * AlaskaAirFareRequest;
    decimal totalFare;
    string airline = "Alaska";
|};

service /alaska on new http:Listener(8083) {
    resource function post airfare(AlaskaAirFareRequest airfareRequest) returns AlaskaAirfareResponse|http:InternalServerError {
        FareRequest fareReq = {sourceCode: airfareRequest.sCode, destCode: airfareRequest.dCode, passengers: airfareRequest.nPassengers};
        FareResponse|error fareResp = processAirfaceRequest(fareReq);
        if fareResp is error {
            return <http:InternalServerError>{body: {message: fareResp.message(), details: fareResp.detail().toString()}};
        } else {
            return {totalFare: fareResp.totalFare, ...airfareRequest};
        }
    }
}