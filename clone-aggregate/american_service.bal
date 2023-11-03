import ballerina/http;

type AmericanAirFareRequest record {|
    string sourceAirport;
    string destinationAirport;
    int numberOfPassengers;
|};

type AmericanAirfareResponse record {|
    * AmericanAirFareRequest;
    decimal totalFare;
    string airline = "American";
|};

service /american on new http:Listener(8082) {
    resource function post airfare(AmericanAirFareRequest airfareRequest) returns AmericanAirfareResponse|http:InternalServerError {
        FareRequest fareReq = {sourceCode: airfareRequest.sourceAirport, destCode: airfareRequest.destinationAirport, passengers: airfareRequest.numberOfPassengers};
        FareResponse|error fareResp = processAirfaceRequest(fareReq);
        if fareResp is error {
            return <http:InternalServerError>{body: {message: fareResp.message(), details: fareResp.detail().toString()}};
        } else {
            return {totalFare: fareResp.totalFare, ...airfareRequest};
        }
    }
}