public isolated class Graph {
    private final string[] edges = [];
    isolated function addEdge(string node1, string node2) {
        lock {
            string edge = string `"${node1}" -> "${node2}";` + "\n";
            self.edges.push(edge);
        }
    }

    public isolated function toString() returns string {
        string graphStr = "digraph \"DataflowGraph\" {\n";
        graphStr += "node [shape=record];\n";

        lock {
            foreach var edge in self.edges {
                graphStr += edge;
            }
        }

        graphStr += "}\n";
        return graphStr;
    }
}
