type SwitchNodeProperties record {|
    *NodeProperties;
    "SwitchNode" templateId = "SwitchNode";
    SwitchCaseBlock[] cases;
    DefaultCaseBlock? defaultCase = ();

|};

type SwitchCaseBlock record {|
    BalExpression expression;
    string[] nodeIds;
|};

type DefaultCaseBlock record {|
    string[] nodeIds;
|};