import ballerina/lang.runtime;
import ballerina/random;

const float EARTH_RADIUS = 6371; // Earth radius in kilometers

type Airport readonly & record {
    string code;
    string name;
    string state;
    float latitude;
    float longitude;
};

type FareRequest record {|
    string sourceCode;
    string destCode;
    int passengers;
|};

type FareResponse record {|
    string sourceCode;
    string destCode;
    int passengers;
    decimal totalFare;
|};

final readonly & table<Airport> key(code) airportTable = table [
    {code: "ATL", name: "Hartsfield-Jackson Atlanta International Airport", state: "GA", latitude: 33.6407, longitude: -84.4277},
    {code: "LAX", name: "Los Angeles International Airport", state: "CA", latitude: 33.9416, longitude: -118.4085},
    {code: "ORD", name: "O'Hare International Airport", state: "IL", latitude: 41.9742, longitude: -87.9073},
    {code: "DFW", name: "Dallas/Fort Worth International Airport", state: "TX", latitude: 32.8998, longitude: -97.0403},
    {code: "DEN", name: "Denver International Airport", state: "CO", latitude: 39.8561, longitude: -104.6737},
    {code: "JFK", name: "John F. Kennedy International Airport", state: "NY", latitude: 40.6413, longitude: -73.7781},
    {code: "SFO", name: "San Francisco International Airport", state: "CA", latitude: 37.6213, longitude: -122.3790},
    {code: "SEA", name: "Seattle-Tacoma International Airport", state: "WA", latitude: 47.4502, longitude: -122.3088},
    {code: "MIA", name: "Miami International Airport", state: "FL", latitude: 25.7959, longitude: -80.2870},
    {code: "MCO", name: "Orlando International Airport", state: "FL", latitude: 28.4312, longitude: -81.3080}
];

function processAirfaceRequest(FareRequest airfareRequest) returns FareResponse|error {
    check simulatedLatency();
    var {sourceCode, destCode, passengers} = airfareRequest;
    decimal fare = check calculateAirfare(sourceCode, destCode, passengers);
    int randomDiscount = check random:createIntInRange(10, 30);
    decimal discountedFare = fare - (fare * randomDiscount / 100);
    return {totalFare: discountedFare.round(2), ...airfareRequest};
}

function calculateDistance(Airport sourceAirport, Airport destAirport) returns decimal {
    float lat1 = sourceAirport.latitude;
    float lon1 = sourceAirport.longitude;
    float lat2 = destAirport.latitude;
    float lon2 = destAirport.longitude;

    // Convert latitude and longitude from degrees to radians
    float lat1Rad = lat1 * (float:PI / 180.0);
    float lon1Rad = lon1 * (float:PI / 180.0);
    float lat2Rad = lat2 * (float:PI / 180.0);
    float lon2Rad = lon2 * (float:PI / 180.0);

    // Haversine formula
    float dlon = lon2Rad - lon1Rad;
    float dlat = lat2Rad - lat1Rad;
    float a = (float:sin(dlat / 2)).pow(2) + float:cos(lat1Rad) * float:cos(lat2Rad) * (float:sin(dlon / 2)).pow(2);
    float c = 2 * float:atan2(float:sqrt(a), float:sqrt(1 - a));
    float distance = EARTH_RADIUS * c;

    // Convert distance to an integer (e.g., in kilometers)
    return <decimal>distance;
}

function calculateAirfare(string sourceCode, string destCode, int passengers) returns decimal|error {
    Airport? sourceAirport = airportTable.get(sourceCode);
    if sourceAirport is () {
        return error("Source airport not found", sourceAirport = sourceCode);
    }

    Airport? destAirport = airportTable.get(destCode);
    if destAirport is () {
        return error("Destination airport not found", destAirport = destCode);
    }

    decimal distance = calculateDistance(sourceAirport, destAirport);
    decimal baseFare = 100; // Assume a base fare for the calculation
    return (baseFare + distance) * passengers;
}

function simulatedLatency() returns error? {
    int max = 500;
    int min = 30;
    decimal delay = <decimal> check random:createIntInRange(min, max);
    runtime:sleep(delay/1000);
}
