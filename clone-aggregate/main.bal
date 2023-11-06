// import ballerina/io;
import ballerina/http;
import ballerina/log;

import samjs/eggplant as _;

type AirfareRequest record {|
    string sourceCode;
    string destCode;
    int passengers;
|};

type AirfareResponse record {|
    string sourceCode;
    string destCode;
    int passengers;
    decimal totalFare;
    string airline;
|};

final http:Client alaskaAirline = check new ("http://localhost:8083/alaska");
final http:Client deltaAirline = check new ("http://localhost:8081/delta");
final http:Client americanAirline = check new ("http://localhost:8082/american");

// TODO How to achieve reusability of certain dataflow sequences?

service /abcflights on new http:Listener(9091) {

    // Make three calls to Delta, American, Alaska and return the cheapest response.
    // resource function post airfare/cheapest(AirfareRequest airfareRequest) returns AirfareResponse|http:InternalServerError {
    //     final AirfareRequest & readonly fareReq = airfareRequest.cloneReadOnly();

    //     worker LogAirfareRequest {
    //         log:printDebug("Airfare request received", sourceCode = fareReq.sourceCode, destCode = fareReq.destCode, passengers = fareReq.passengers);
    //     }

    //     worker CreateAlaskaFareRequest {
    //         var alaskaFareRequest = transfromToAlaskaFareRequest(fareReq);
    //         alaskaFareRequest -> GetAlaskaTotalFare;
    //     }

    //     worker GetAlaskaTotalFare returns error? {
    //         AlaskaAirFareRequest alaskaFareReq = <- CreateAlaskaFareRequest;
    //         AlaskaAirfareResponse alaskaFareResp = check alaskaAirline->/airfare.post(alaskaFareReq);
    //         alaskaFareResp -> TransformAlaskaFareResponse;
    //     }

    //     worker TransformAlaskaFareResponse returns AirfareResponse|error {
    //         AlaskaAirfareResponse alaskaFareResp = check <- GetAlaskaTotalFare;
    //         return transformAlaskaFareResponse(alaskaFareResp);
    //     }

    //     worker CreateDeltaFareRequest {
    //         var deltaFareRequest = transfromToDeltaFareRequest(fareReq);
    //         deltaFareRequest -> GetDeltaTotalFare;
    //     }

    //     worker GetDeltaTotalFare returns error? {
    //         DeltaAirFareRequest deltaFareRequest = <- CreateDeltaFareRequest;
    //         DeltaAirfareResponse deltaFareResponse = check deltaAirline->/airfare.post(deltaFareRequest);
    //         deltaFareResponse -> TransformDeltaFareResponse;
    //     }

    //     worker TransformDeltaFareResponse returns AirfareResponse|error {
    //         DeltaAirfareResponse deltaFareResponse = check <- GetDeltaTotalFare;
    //         return transformDeltaFareResponse(deltaFareResponse);
    //     }

    //     worker CreateAmericanFareRequest {
    //         var americanFareRequest = transfromToAmericanFareRequest(fareReq);
    //         americanFareRequest -> GetAmericanTotalFare;
    //     }

    //     worker GetAmericanTotalFare returns error? {
    //         AmericanAirFareRequest americanFareRequest = <- CreateAmericanFareRequest;
    //         AmericanAirfareResponse americanFareResponse = check americanAirline->/airfare.post(americanFareRequest);
    //         americanFareResponse -> TransformAmericanFareResponse;
    //     }

    //     worker TransformAmericanFareResponse returns AirfareResponse|error {
    //         AmericanAirfareResponse americanFareResponse = check <- GetAmericanTotalFare;
    //         return transformAmericanFareResponse(americanFareResponse);
    //     }

    //     worker FindCheapestFareResponse returns error? {
    //         map<AirfareResponse|error> mapResult = wait {alaska: TransformAlaskaFareResponse, delta: TransformDeltaFareResponse, american: TransformAmericanFareResponse};

    //         // TODO Write the following logic using df nodes
    //         decimal lowestFare = <decimal>int:MAX_VALUE;
    //         AirfareResponse? cheapestResp = ();
    //         foreach var key in mapResult.keys() {
    //             var result = mapResult[key];
    //             if result is AirfareResponse {
    //                 if result.totalFare < lowestFare {
    //                     lowestFare = result.totalFare;
    //                     cheapestResp = result;
    //                 }
    //             } else {
    //                 log:printError("Error occurred while invoking airline service", airline = key, 'error = result);
    //             }
    //         }

    //         if cheapestResp is () {
    //             return error("No valid response received from any airline service");
    //         }

    //         cheapestResp -> LogAirfareResponse;
    //         cheapestResp -> function;
    //     }

    //     worker LogAirfareResponse returns error? {
    //         AirfareResponse cheapestResp = check <- FindCheapestFareResponse;
    //         log:printDebug("Airfare response sent", sourceCode = cheapestResp.sourceCode, destCode = cheapestResp.destCode, passengers = cheapestResp.passengers, totalFare = cheapestResp.totalFare, airline = cheapestResp.airline);
    //     }

    //     AirfareResponse|error cheapestResp = <- FindCheapestFareResponse;
    //     if cheapestResp is error {
    //         return http:INTERNAL_SERVER_ERROR;
    //     } else {
    //         return cheapestResp;
    //     }
    // }

    // Make three calls to Delta, American, Alaska and return the fastest response.
    resource function post airfare/fastest(AirfareRequest airfareRequest) returns AirfareResponse|http:InternalServerError {
        final AirfareRequest & readonly fareReq = airfareRequest.cloneReadOnly();

        worker LogAirfareRequest {
            log:printDebug("Airfare request received", sourceCode = fareReq.sourceCode, destCode = fareReq.destCode, passengers = fareReq.passengers);
        }

        worker CreateAlaskaFareRequest {
            var alaskaFareRequest = transfromToAlaskaFareRequest(fareReq);
            alaskaFareRequest -> GetAlaskaTotalFare;
        }
    

        worker GetAlaskaTotalFare returns error? {
            AlaskaAirFareRequest alaskaFareReq = <- CreateAlaskaFareRequest;
            AlaskaAirfareResponse alaskaFareResp = check alaskaAirline->/airfare.post(alaskaFareReq);
            alaskaFareResp -> TransformAlaskaFareResponse;
        }

        worker TransformAlaskaFareResponse returns AirfareResponse|error {
            AlaskaAirfareResponse alaskaFareResp = check <- GetAlaskaTotalFare;
            return transformAlaskaFareResponse(alaskaFareResp);
        }

        worker CreateDeltaFareRequest {
            var deltaFareRequest = transfromToDeltaFareRequest(fareReq);
            deltaFareRequest -> GetDeltaTotalFare;
        }

        worker GetDeltaTotalFare returns error? {
            DeltaAirFareRequest deltaFareRequest = <- CreateDeltaFareRequest;
            DeltaAirfareResponse deltaFareResponse = check deltaAirline->/airfare.post(deltaFareRequest);
            deltaFareResponse -> TransformDeltaFareResponse;
        }

        worker TransformDeltaFareResponse returns AirfareResponse|error {
            DeltaAirfareResponse deltaFareResponse = check <- GetDeltaTotalFare;
            return transformDeltaFareResponse(deltaFareResponse);
        }

        worker CreateAmericanFareRequest {
            var americanFareRequest = transfromToAmericanFareRequest(fareReq);
            americanFareRequest -> GetAmericanTotalFare;
        }

        worker GetAmericanTotalFare returns error? {
            AmericanAirFareRequest americanFareRequest = <- CreateAmericanFareRequest;
            AmericanAirfareResponse americanFareResponse = check americanAirline->/airfare.post(americanFareRequest);
            americanFareResponse -> TransformAmericanFareResponse;
        }

        worker TransformAmericanFareResponse returns AirfareResponse|error {
            AmericanAirfareResponse americanFareResponse = check <- GetAmericanTotalFare;
            return transformAmericanFareResponse(americanFareResponse);
        }

        worker FindFastestFareResponse returns error? {
            // Fastest response can be an error response as well
            AirfareResponse airfareResp = check wait TransformAlaskaFareResponse | TransformDeltaFareResponse | TransformAmericanFareResponse;
            airfareResp -> LogAirfareResponse;
            airfareResp -> function;
        }

        worker LogAirfareResponse returns error? {
            AirfareResponse airfareResp = check <- FindFastestFareResponse;
            log:printDebug("Airfare response sent", sourceCode = airfareResp.sourceCode, destCode = airfareResp.destCode, passengers = airfareResp.passengers, totalFare = airfareResp.totalFare, airline = airfareResp.airline);
        }

        AirfareResponse|error airfareResp = <- FindFastestFareResponse;
        if airfareResp is error {
            return http:INTERNAL_SERVER_ERROR;
        } else {
            return airfareResp;
        }
    }
}

isolated function transfromToAlaskaFareRequest(AirfareRequest airfareReq) returns AlaskaAirFareRequest => {
    sCode: airfareReq.sourceCode,
    dCode: airfareReq.destCode,
    nPassengers: airfareReq.passengers
};

isolated function transfromToDeltaFareRequest(AirfareRequest airfareReq) returns DeltaAirFareRequest => {
    srcAirport: airfareReq.sourceCode,
    destAirport: airfareReq.destCode,
    noOfPassengers: airfareReq.passengers
};

isolated function transfromToAmericanFareRequest(AirfareRequest airfareReq) returns AmericanAirFareRequest => {
    sourceAirport: airfareReq.sourceCode,
    destinationAirport: airfareReq.destCode,
    numberOfPassengers: airfareReq.passengers
};

isolated function transformAlaskaFareResponse(AlaskaAirfareResponse alaskaAirFareResponse) returns AirfareResponse => {
    sourceCode: alaskaAirFareResponse.sCode,
    destCode: alaskaAirFareResponse.dCode,
    passengers: alaskaAirFareResponse.nPassengers,
    totalFare: alaskaAirFareResponse.totalFare,
    airline: alaskaAirFareResponse.airline
};

isolated function transformDeltaFareResponse(DeltaAirfareResponse deltaAirFareResponse) returns AirfareResponse => {
    sourceCode: deltaAirFareResponse.srcAirport,
    destCode: deltaAirFareResponse.destAirport,
    passengers: deltaAirFareResponse.noOfPassengers,
    totalFare: deltaAirFareResponse.totalFare,
    airline: deltaAirFareResponse.airline
};

isolated function transformAmericanFareResponse(AmericanAirfareResponse americanAirFareResponse) returns AirfareResponse => {
    sourceCode: americanAirFareResponse.sourceAirport,
    destCode: americanAirFareResponse.destinationAirport,
    passengers: americanAirFareResponse.numberOfPassengers,
    totalFare: americanAirFareResponse.totalFare,
    airline: americanAirFareResponse.airline
};

