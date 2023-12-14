
type HttpGetNodeProperties record {|
    *NodeProperties;
    "HttpGetNode" templateId = "HttpGetNode";
    string outputType;
    string clientName;
    // We may need to introduce a new type for actions. This is a temporary solution.
    BalExpression resourceAccessAction; // httpEp->/foo/bar.get()
|};
