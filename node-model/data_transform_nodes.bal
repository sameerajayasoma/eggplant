
type TransformNodeProperties record {|
    *NodeProperties;
    "TransformNode" templateId = "TransformNode";
    string outputType;
    BalExpression expression; // Data mapper expression

|};

type CloneNodeProperties record {|
    *NodeProperties;
    "CloneNode" templateId = "CloneNode";
|};

type ModifyNodeProperties record {|
    *NodeProperties;
    "ModifyNode" templateId = "ModifyNode";
    string outputType?;
    BalExpression[] expressions; 
|};

type FilterNodeProperties record {|
    *NodeProperties;
    "FilterNode" templateId = "FilterNode";
    BalExpression expression; // boolean condition
|};


type SchemaValidateNodeProperties record {|
    *NodeProperties;
    "SchemaValidateNode" templateId = "SchemaValidateNode";
    string schema; // Ballerina type definition
|};

type RuleValidateNodeProperties record {|
    *NodeProperties;
    "RuleValidateNode" templateId = "RuleValidateNode";
    BalExpression[] rules;
|};