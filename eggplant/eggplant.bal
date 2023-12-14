# Defines Eggplant node attributes.
public type NodeData record {|
    # Base64 encoded string of the node details.
    string layout;
|};

# Inidiates that the worker is an Eggplant node
public const annotation NodeData Node on source worker;

