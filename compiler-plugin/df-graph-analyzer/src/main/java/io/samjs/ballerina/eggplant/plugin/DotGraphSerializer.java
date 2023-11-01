package io.samjs.ballerina.eggplant.plugin;

import java.util.ArrayList;
import java.util.List;

public class DotGraphSerializer {
    private final List<String> edges = new ArrayList<>();
    void addEdge(String node1, String node2) {
//        String edge = string `"${node1}" -> "${node2}";` + "\n";
        String edge = "\"" + node1 +"\" -> \"" + node2 + "\";\n";
        edges.add(edge);
    }

    public String toString() {
        String graphStr = "digraph \"DataflowGraph\" {\n";
        graphStr += "node [shape=record];\n";

        for (String edge : edges) {
            graphStr = graphStr.concat(edge);
        }

        graphStr += "}\n";
        return graphStr;
    }
}
