import ballerina/http;
import ballerina/log;

public isolated class HttpErrorHandlerNode {
    *TargetErrorHandlerNode;
    private final string id;
    private TargetNode targetNode = dummyNode;

    public function init(string id) {
        self.id = string `HttpErrorHandlerNode:${id}`;
    }

    public function targetEdge(TargetNode node) {
        lock {
            self.targetNode = node;
        }
    }

    isolated function getId() returns string {
        return self.id;
    }

    public isolated function send(error e, MessageContext msgCtx) returns error? {
        log:printDebug(string `HttpErrorHandlerNode: ${self.id}`);
        log:printError("Error occurred in HTTP client: ", 'error = e);
        return e;
    }

    public isolated function serialize(Graph graph) {
        lock {
            graph.addEdge(self.id, self.targetNode.getId());
            self.targetNode.serialize(graph);
        }
    }
}

public isolated class HttpPostClientNode {
    *IntermediateNode;
    private final string id;
    private TargetNode targetNode = dummyNode;
    private TargetErrorHandlerNode targetErrorHandler = dummyErrorHandlerNode;
    private final http:Client httpClient;
    private final Value path;

    public function init(string id, http:Client httpClient, Value path) {
        self.id = string `HttpPostClientNode:${id}`;
        self.httpClient = httpClient;
        self.path = path;
    }

    isolated function getId() returns string {
        return self.id;
    }

    public function targetEdge(TargetNode node) {
        lock {
            self.targetNode = node;
        }
    }

    public function targetErrorHandlerEdge(TargetErrorHandlerNode node) {
        lock {
            self.targetErrorHandler = node;
        }
    }

    public isolated function send(anydata message, MessageContext msgCtx) returns error? {
        log:printDebug(string `HttpPostClientNode: ${self.id}`);

        string path;
        lock {
            if self.path.kind == VALUE_KIND_LITERAL {
                path = self.path.value.toString();
            } else if self.path.kind == VALUE_KIND_VARIABLE {
                path = msgCtx.getVariable(self.path.value.toString()).toString();
            } else {
                panic error("Invalid value type");
            }
        }

        anydata|error response = self.httpClient->post(path, message);
        if response is error {
            lock {
                check self.targetErrorHandler.send(response, msgCtx);
            }

        } else {
            lock {
                check self.targetNode.send(response.clone(), msgCtx);
            }
        }
    }

    public isolated function serialize(Graph graph) {
        lock {
            graph.addEdge(self.id, self.targetNode.getId());
            self.targetNode.serialize(graph);
            graph.addEdge(self.id, self.targetErrorHandler.getId());
            self.targetErrorHandler.serialize(graph);
        }
    }
}

// TODO: Need to support query params
public isolated class HttpGetClientNode {
    *IntermediateNode;
    private final string id;
    private TargetNode targetNode = dummyNode;
    private TargetErrorHandlerNode targetErrorHandler = dummyErrorHandlerNode;
    private final http:Client httpClient;
    private final Value path;

    public function init(string id, http:Client httpClient, Value path) {
        self.id = string `HttpGetClientNode:${id}`;
        self.httpClient = httpClient;
        self.path = path;
    }

    isolated function getId() returns string {
        return self.id;
    }

    public function targetEdge(TargetNode node) {
        lock {
            self.targetNode = node;
        }
    }

    public function targetErrorHandlerEdge(TargetErrorHandlerNode node) {
        lock {
            self.targetErrorHandler = node;
        }
    }

    public isolated function send(anydata message, MessageContext msgCtx) returns error? {
        log:printDebug(string `HttpGetClientNode: ${self.id}`);

        string path;
        lock {
            if self.path.kind == VALUE_KIND_LITERAL {
                path = self.path.value.toString();
            } else if self.path.kind == VALUE_KIND_VARIABLE {
                path = msgCtx.getVariable(self.path.value.toString()).toString();
            } else {
                panic error("Invalid value type");
            }
        }

        anydata|error response = check self.httpClient->get(path);
        if response is error {
            lock {
                check self.targetErrorHandler.send(response, msgCtx);
            }

        } else {
            lock {
                check self.targetNode.send(response.clone(), msgCtx);
            }
        }
    }

    public isolated function serialize(Graph graph) {
        lock {
            graph.addEdge(self.id, self.targetNode.getId());
            self.targetNode.serialize(graph);
            graph.addEdge(self.id, self.targetErrorHandler.getId());
            self.targetErrorHandler.serialize(graph);
        }
    }
}

public isolated class HttpCallerNode {
    *TargetNode;
    private final string id;
    private final int httpStatusCode;

    public function init(string id, int httpStatusCode = http:STATUS_OK) {
        self.id = string `HttpCallerNode:${id}`;
        self.httpStatusCode = httpStatusCode;
    }

    isolated function getId() returns string {
        return self.id;
    }

    public isolated function send(anydata message, MessageContext msgCtx) returns error? {
        log:printDebug(string `HttpCallerNode: ${self.id}`);
        http:Caller caller = check msgCtx.getSystemVariable("http_caller").ensureType();
        check caller->respond(<http:Ok>{body: message});
    }

    public isolated function serialize(Graph graph) {
        return;
    }
}

// HttpResourcePathNode creates an HTTP resource path from an array of Value nodes and set it to a variable with the given name
public isolated class HttpResourcePathNode {
    *IntermediateNode;
    private final string id;
    private TargetNode targetNode = dummyNode;
    private final string targetVariableName;
    private final Value[] pathSegments;

    public function init(string id, string targetVariableName, readonly & Value[] pathSegments) {
        self.id = string `HttpResourcePathNode:${id}`;
        self.targetVariableName = targetVariableName;
        self.pathSegments = pathSegments;
    }

    isolated function getId() returns string {
        return self.id;
    }

    public function targetEdge(TargetNode node) {
        lock {
            self.targetNode = node;
        }
    }

    public isolated function send(anydata message, MessageContext msgCtx) returns error? {
        log:printDebug(string `HttpResourcePathNode: ${self.id}`);

        string path;
        lock {
            string[] pathSegments = [];

            foreach Value pathSegment in self.pathSegments {
                if pathSegment.kind == VALUE_KIND_LITERAL {
                    pathSegments.push(pathSegment.value.toString());
                } else if pathSegment.kind == VALUE_KIND_VARIABLE {
                    pathSegments.push(msgCtx.getVariable(pathSegment.value.toString()).toString());
                } else {
                    panic error("Invalid path value type");
                }
            }

            path = "/" + string:'join("/", ...pathSegments);
        }

        lock {
            msgCtx.addVariable(self.targetVariableName, path);
            check self.targetNode.send(message.clone(), msgCtx);
        }
    }

    public isolated function serialize(Graph graph) {
        lock {
            graph.addEdge(self.id, self.targetNode.getId());
            self.targetNode.serialize(graph);
        }
    }
}
