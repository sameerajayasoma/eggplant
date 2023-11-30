
// NodeTemplate vs Node 
// NodeTemplate is a schema for a node type. It describes node properties, ports, etc.
// Node is an instance of a node template. It has a unique id, name, etc.

// Each node type is associated with node type schema that describes nodes properties, ports, etc.
// This node template or schema will be hardcoded in the tool initially.

type Node record {|
    string id;
    string templateId;
    InputPort[] inputPorts;
    OutputPort[] outputPorts;
    Location location;
    NodeProperties properties;
|};

type InputPort record {|
    string id;
    string 'type;
    string name;
    //Node sender; // Node.id
    string sender;
|};

type OutputPort record {|
    string id;
    string 'type;
    //Node receiver;  // Node.id
    string receiver;
|};

type NodeProperty record {|
    string id;
    string 'type;
    string name;
    string value;
|};

type Location record {|
    string filename;
    LinePosition startLine;
    LinePosition endLine;
|};

type LinePosition record {|
    int line;
    int column;
|};

// Node specific properties 
// Node properties are defined in the node template schema.

type NodeProperties record {|
    string templateId;
    string name;
|};

type TransformNodeProperties record {|
    *NodeProperties;
    string templateId = "TransformNode";
    string outputType;
    string expression;

|};

type CloneNodeProperties record {|
    *NodeProperties;
    string templateId = "CloneNode";
|};

type SwitchNodeProperties record {|
    *NodeProperties;
    string templateId = "SwitchNode";
    SwitchCaseBlock[] cases;
    DefaultCaseBlock? defaultCase = ();

|};

type SwitchCaseBlock record {|
    string expression;
    OutputPort[] nodes;
|};

type DefaultCaseBlock record {|
    OutputPort[] nodes;
|};
