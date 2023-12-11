# Defines the template name of the ModifyNode
public const ModifyNode = "ModifyNode";

# Defines the position of a node on the canvas
public type CanvasPosition record {|
    # The x coordinate of the node
    int x;
    # The y coordinate of the node
    int y;
|};

# Defines Eggplant node attributes.
public type NodeData record {|
    # The template name of the node
    string template;
    # The display name of the node
    string displayName;
    # The position of the node on the canvas
    CanvasPosition canvasPosition;
|};

# Inidiates that the worker is an Eggplant node
public const annotation NodeData Node on source worker;

