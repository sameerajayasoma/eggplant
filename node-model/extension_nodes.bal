
type FunctionCallNodeProperties record {|
    *NodeProperties;
    "FunctionCallNode" templateId = "FunctionCallNode";
    string outputType; // Do we need to specify the variable name as well here?
    BalExpression expression;
|};

type CodeNodeProperties record {|
    *NodeProperties;
    "CodeNode" templateId = "CodeNode";
    CodeBlock codeBlock;
|};