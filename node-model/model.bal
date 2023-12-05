
type Flow record {|
    string id;
    string name;
    Node[] nodes;
    string balFilename;
|};

type Node record {|
    string id;
    string templateId;
    InputPort[] inputPorts;
    OutputPort[] outputPorts;
    CodeLocation codeLocation;
    CanvasPosition canvasPosition;
    NodeProperties properties;
|};

type InputPort record {|
    string id;
    string 'type;
    string name;
    string sender;
|};

type OutputPort record {|
    string id;
    string 'type;
    string receiver;
|};

type CodeLocation record {|
    LinePosition startLine;
    LinePosition endLine;
|};

type CanvasPosition record {|
    int x;
    int y;
|};

type LinePosition record {|
    int line;
    int column;
|};

type NodeProperties record {|
    string templateId;
    string name;
|};

type BalExpression record {|
    string expression;
    CodeLocation location;
|};
