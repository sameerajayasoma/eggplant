 
public type DataflowNode distinct isolated object {
    public isolated function serialize(Graph graph);
    isolated function getId() returns string;
};

public type SourceNode distinct isolated object {
    *DataflowNode;
};

public type TargetNode distinct isolated object {
    *DataflowNode;
    public isolated function send(anydata message, MessageContext msgCtx) returns error?;
};

public type TargetErrorHandlerNode distinct isolated object {
    *DataflowNode;
    public isolated function send(error e, MessageContext msgCtx) returns error?;
};

public type IntermediateNode distinct isolated object {
    *SourceNode;
    *TargetNode;
};

public const VALUE_KIND_LITERAL = "literal";
public const VALUE_KIND_VARIABLE = "variable";
public const VALUE_KIND_EXPRESSION = "expression";

public type VALUE_KIND VALUE_KIND_LITERAL|VALUE_KIND_VARIABLE|VALUE_KIND_EXPRESSION;

# Description.
public type Value readonly & record {|
    VALUE_KIND kind = VALUE_KIND_LITERAL;
    anydata| isolated function (anydata) returns anydata value;
|};


// TODO: This should maintain scopes of variables 
public isolated class MessageContext {
    private final map<readonly & anydata> variables = {};
    private final map<readonly & anydata|isolated object {}> systemVariables = {};

    public isolated function addVariable(string name, readonly & anydata value) {
        lock {
            self.variables[name] = value;
        }
    }

    public isolated function getVariable(string name) returns any {
        lock {
            return self.variables.get(name);
        }
    }

    public isolated function removeVariable(string name) returns any {
        lock {
            return self.variables.remove(name);
        }
    }

    public isolated function getVariables() returns map<readonly & anydata> {
        lock {
            return self.variables.clone();
        }
    }

    public isolated function addSystemVariable(string name, readonly & anydata|isolated object {} value) {
        lock {
            self.systemVariables[name] = value;
        }
    }

    public isolated function getSystemVariable(string name) returns readonly & anydata|isolated object {} {
        lock {
            return self.systemVariables.get(name);
        }
    }
}

