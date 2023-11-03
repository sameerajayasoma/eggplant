import ballerina/http;

type DeltaAirFareRequest record {|
    string srcAirport;
    string destAirport;
    int noOfPassengers;
|};

type DeltaAirfareResponse record {|
    *DeltaAirFareRequest;
    decimal totalFare;
    string airline = "Delta";
|};

service /delta on new http:Listener(8081) {
    resource function post airfare(DeltaAirFareRequest airfareRequest) returns DeltaAirfareResponse|http:InternalServerError {
        FareRequest fareReq = {sourceCode: airfareRequest.srcAirport, destCode: airfareRequest.destAirport, passengers: airfareRequest.noOfPassengers};
        FareResponse|error fareResp = processAirfaceRequest(fareReq);
        if fareResp is error {
            return <http:InternalServerError>{body: {message: fareResp.message(), details: fareResp.detail().toString()}};
        } else {
            return {totalFare: fareResp.totalFare, ...airfareRequest};
        }
    }
}
