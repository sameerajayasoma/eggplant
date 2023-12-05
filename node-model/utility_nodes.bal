type LogNodeProperties record {|
    *NodeProperties;
    "LogNode" templateId = "LogNode";
    LogLevel level;
    string message;
    LogKeyValuePair[] keyValuePairs;
|};

type LogKeyValuePair record {|
    string key;
    BalExpression value;
|};

enum LogLevel {
    DEBUG,
    ERROR,
    INFO,
    WARN
}