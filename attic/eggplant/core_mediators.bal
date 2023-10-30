import ballerina/log;

isolated distinct class DummyNode {
    *IntermediateNode;

    isolated function getId() returns string {
        return "";
    }

    public isolated function send(anydata message, MessageContext msgCtx) returns error? {
        return;
    }

    public isolated function serialize(Graph graph) {
        return;
    }
}

DummyNode dummyNode = new;

isolated distinct class DummyErrorHandlerNode {
    *TargetErrorHandlerNode;

    isolated function getId() returns string {
        return "";
    }

    public isolated function send(error e, MessageContext msgCtx) returns error? {
        return;
    }

    public isolated function serialize(Graph graph) {
        return;
    }
}

DummyErrorHandlerNode dummyErrorHandlerNode = new;

public isolated class CloneNode {
    *IntermediateNode;
    private final string id;
    private final TargetNode[] targetNodes = [];

    public function init(string id) {
        self.id = string `CloneNode:${id}`;
    }

    public function targetEdge(TargetNode node) {
        lock {
            self.targetNodes.push(node);
        }
    }

    public isolated function send(anydata message, MessageContext msgCtx) returns error? {
        log:printDebug(string `CloneNode: ${self.id}`);
        lock {
            // TODO: Invoke target nodes in parallel
            foreach var node in self.targetNodes {
                check node.send(message.clone(), msgCtx);
            }
        }
    }

    public isolated function serialize(Graph graph) {
        lock {
            foreach var targetNode in self.targetNodes {
                graph.addEdge(self.id, targetNode.getId());
                targetNode.serialize(graph);
            }
        }
        return;
    }

    isolated function getId() returns string {
        return self.id;
    }
}

public isolated class FilterNode {
    *IntermediateNode;
    private final string id;
    private final TargetNode thenNode;
    private final TargetNode elseNode;
    private final isolated function (anydata) returns boolean filterFunc;

    public function init(string id, TargetNode thenNode, TargetNode elseNode, isolated function (anydata) returns boolean filterFunc) {
        self.id = string `FilterNode:${id}`;
        self.thenNode = thenNode;
        self.elseNode = elseNode;
        self.filterFunc = filterFunc;
    }

    public isolated function send(anydata message, MessageContext msgCtx) returns error? {
        log:printDebug(string `FilterNode: ${self.id}`);
        if self.filterFunc(message) {
            check self.thenNode.send(message, msgCtx);
        } else {
            check self.elseNode.send(message, msgCtx);
        }
    }

    public isolated function serialize(Graph graph) {
        graph.addEdge(self.id, self.thenNode.getId());
        self.thenNode.serialize(graph);
        graph.addEdge(self.id, self.elseNode.getId());
        self.elseNode.serialize(graph);
        return;
    }

    isolated function getId() returns string {
        return self.id;
    }
}

public isolated class MapNode {
    *IntermediateNode;
    private final string id;
    private final TargetNode targetNode;
    private final isolated function (anydata) returns anydata mapFunc;

    public function init(string id, TargetNode targetNode, isolated function (anydata) returns anydata mapFunc) {
        self.id = string `MapNode:${id}`;
        self.targetNode = targetNode;
        self.mapFunc = mapFunc;
    }

    public isolated function send(anydata message, MessageContext msgCtx) returns error? {
        log:printDebug(string `MapNode: ${self.id}`);
        check self.targetNode.send(self.mapFunc(message), msgCtx);
    }

    public isolated function serialize(Graph graph) {
        graph.addEdge(self.id, self.targetNode.getId());
        self.targetNode.serialize(graph);
        return;
    }

    isolated function getId() returns string {
        return self.id;
    }
}

public isolated class ActionNode {
    *TargetNode;
    private final string id;
    private final isolated function (anydata) actionFunc;

    public function init(string id, isolated function (anydata) actionFunc) {
        self.id = string `ActionNode:${id}`;
        self.actionFunc = actionFunc;
    }

    public isolated function send(anydata message, MessageContext msgCtx) returns error? {
        log:printDebug(string `ActionNode: ${self.id}`);
        self.actionFunc(message);
    }

    public isolated function serialize(Graph graph) {
        return;
    }

    isolated function getId() returns string {
        return self.id;
    }
}

public type LogKeyValue readonly & record {|
    string key;
    Value value;
|};

public isolated class LoggerNode {
    *IntermediateNode;
    private final string id;
    private final string level;
    private final boolean logMessage;
    private TargetNode targetNode = dummyNode;
    private final LogKeyValue[] keyValuePairs;

    public function init(string id, string level, boolean logMessage = false, readonly & LogKeyValue[] keyValuePairs = []) {
        self.id = string `LoggerNode:${id}`;
        self.level = level;
        if level !is "INFO"|"DEBUG"|"ERROR"|"WARN" {
            panic error("Invalid log level");
        }
        self.logMessage = logMessage;
        self.keyValuePairs = keyValuePairs;
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
        log:printDebug(string `LoggerNode: ${self.id}`);

        map<string> kvMap;
        lock {
            map<string> _kvMap = {};
            foreach var keyValue in self.keyValuePairs {
                string value;
                if keyValue.value.kind == VALUE_KIND_LITERAL {
                    value = keyValue.value.value.toString();
                } else if keyValue.value.kind == VALUE_KIND_VARIABLE {
                    value = msgCtx.getVariable(keyValue.value.value.toString()).toString();
                } else {
                    panic error("Invalid value type");
                }
                _kvMap[keyValue.key] = value;
            }
            kvMap = _kvMap.clone();
        }

        string msg = self.logMessage? message.toString() : "";
        if self.level is "INFO" {
            log:printInfo(msg, keyValuePairs = kvMap);
        } else if self.level is "DEBUG" {
            log:printDebug(msg, keyValuePairs = kvMap);
        } else if self.level is "ERROR" {
            log:printError(msg, keyValuePairs = kvMap);
        } else if self.level is "WARN" {
            log:printWarn(msg, keyValuePairs = kvMap);
        }

        lock {
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

public isolated class VariableSetNode {
    *IntermediateNode;
    private final string id;
    private final string variableName;
    private TargetNode targetNode = dummyNode;
    private final isolated function (anydata) returns anydata|error valueFunc;

    public function init(string id, string variableName, isolated function (anydata) returns anydata|error valueFunc) {
        self.id = string `VariableSetNode:${id}`;
        self.variableName = variableName;
        self.valueFunc = valueFunc;
    }

    public function targetEdge(TargetNode node) {
        lock {
            self.targetNode = node;
        }
    }

    public isolated function send(anydata message, MessageContext msgCtx) returns error? {
        log:printDebug(string `VariableSetNode: ${self.id}`);
        anydata value = check self.valueFunc(message);
        msgCtx.addVariable(self.variableName, value.cloneReadOnly());

        lock {
            check self.targetNode.send(message.clone(), msgCtx);
        }
    }

    public isolated function serialize(Graph graph) {
        lock {
            graph.addEdge(self.id, self.targetNode.getId());
            self.targetNode.serialize(graph);
        }
    }

    isolated function getId() returns string {
        return self.id;
    }

}

public isolated class DataMapperNode {
    *IntermediateNode;
    private final string id;
    private TargetNode targetNode = dummyNode;
    private final isolated function (anydata, map<readonly & anydata>) returns anydata|error mapFunc;

    public function init(string id, isolated function (anydata, map<readonly & anydata>) returns anydata|error mapFunc) {
        self.id = string `DataMapperNode:${id}`;
        self.mapFunc = mapFunc;
    }

    public function targetEdge(TargetNode node) {
        lock {
            self.targetNode = node;
        }
    }

    public isolated function send(anydata message, MessageContext msgCtx) returns error? {
        log:printDebug(string `DataMapperNode: ${self.id}`);
        lock {
            check self.targetNode.send(check self.mapFunc(message.clone(), msgCtx.getVariables()), msgCtx);
        }
    }

    public isolated function serialize(Graph graph) {
        lock {
            graph.addEdge(self.id, self.targetNode.getId());
            self.targetNode.serialize(graph);
        }
    }

    isolated function getId() returns string {
        return self.id;
    }
}
