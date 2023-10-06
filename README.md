# Eggplant

## Sample integration
This [sample](./http_sample/main.bal) implements the [Service Orchestration Sample](https://ballerina.io/learn/integration-tutorials/service-orchestration/) using the eggplant API.

Integration diagram 
<img src="./df-dag.svg">

## Steps to run the sample

### 1) Start backend services

```bash
cd backends
bal run hospitalservice.jar
```

### 2) Start the HTTP service

```bash
cd http_sample
bal run
```

### 3) Send a request
```sh
curl -X POST --data @http_sample/request.json http://localhost:8290/healthcare/categories/surgery/reserve --header "Content-Type:application/json"
```

### 4) Verify the response
```json
{
  "appointmentNo": 3,
  "doctorName": "thomas collins",
  "patient": "John Doe",
  "actualFee": 7000,
  "discount": 20,
  "discounted": 5600,
  "paymentID": "b21c674f-aaf9-48c4-a33d-7fe4aa1d8d5f",
  "status": "settled"
}
```