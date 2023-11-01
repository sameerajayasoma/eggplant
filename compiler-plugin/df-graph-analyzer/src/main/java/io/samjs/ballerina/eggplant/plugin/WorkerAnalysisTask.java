package io.samjs.ballerina.eggplant.plugin;

import io.ballerina.compiler.syntax.tree.AsyncSendActionNode;
import io.ballerina.compiler.syntax.tree.BlockStatementNode;
import io.ballerina.compiler.syntax.tree.CheckExpressionNode;
import io.ballerina.compiler.syntax.tree.ExpressionNode;
import io.ballerina.compiler.syntax.tree.ExpressionStatementNode;
import io.ballerina.compiler.syntax.tree.NamedWorkerDeclarationNode;
import io.ballerina.compiler.syntax.tree.NamedWorkerDeclarator;
import io.ballerina.compiler.syntax.tree.Node;
import io.ballerina.compiler.syntax.tree.ReceiveActionNode;
import io.ballerina.compiler.syntax.tree.SimpleNameReferenceNode;
import io.ballerina.compiler.syntax.tree.StatementNode;
import io.ballerina.compiler.syntax.tree.SyncSendActionNode;
import io.ballerina.compiler.syntax.tree.SyntaxKind;
import io.ballerina.compiler.syntax.tree.VariableDeclarationNode;
import io.ballerina.projects.DependencyGraph;
import io.ballerina.projects.DependencyGraph.DependencyGraphBuilder;
import io.ballerina.projects.plugins.AnalysisTask;
import io.ballerina.projects.plugins.SyntaxNodeAnalysisContext;
import io.ballerina.projects.util.ProjectPaths;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;

public class WorkerAnalysisTask<T> implements AnalysisTask<SyntaxNodeAnalysisContext> {

    public static final String DATAFLOW_GRAPH_DOT_FILENAME = "dataflow_graph.dot";
    private static final String FUNC_START_NODE = "FunctionStart";
    private static final String FUNC_END_NODE = "FunctionEnd";
    private static final String FUNC_NODE = "function";

    @Override
    public void perform(SyntaxNodeAnalysisContext analysisContext) {
        if (analysisContext.syntaxTree().hasDiagnostics()) {
            return;
        }

        // Populate the initial dependency graph
        try {
            serializeDependencyGraph(analysisContext);
        } catch (Throwable t) {
            t.printStackTrace();
        }
    }

    private void serializeDependencyGraph(SyntaxNodeAnalysisContext analysisContext) throws Exception {
        DependencyGraphBuilder<String> graphBuilder = DependencyGraphBuilder.getBuilder(FUNC_START_NODE);
        NamedWorkerDeclarator namedWorkerDeclarator = (NamedWorkerDeclarator) analysisContext.node();
        for (NamedWorkerDeclarationNode namedWorkerDeclaration : namedWorkerDeclarator.namedWorkerDeclarations()) {
            String curWorkerName = namedWorkerDeclaration.workerName().text();
            graphBuilder.add(curWorkerName);
            BlockStatementNode blockStatementNode = namedWorkerDeclaration.workerBody();
            for (StatementNode statement : blockStatementNode.statements()) {
                if (statement instanceof ExpressionStatementNode) {
                    // This function processes ASYNC_SEND_ACTION and SYNC_SEND_ACTION nodes
                    processExpressionStmtNode(statement, curWorkerName, graphBuilder);
                } else if (statement instanceof VariableDeclarationNode) {
                    // This function processes RECEIVE_ACTION nodes
                    processVarDeclarationNode(statement, curWorkerName, graphBuilder);
                }
            }
        }

        // Create the dependency graph
        DependencyGraph<String> dependencyGraph = graphBuilder.build();
        DependencyGraphBuilder<String> newGraphBuilder = DependencyGraphBuilder.getBuilder(FUNC_START_NODE);
        newGraphBuilder.mergeGraph(dependencyGraph);

        // Find out nodes that doesn't have any dependents and add function as a dependent.
        for (String node : dependencyGraph.getNodes()) {
            if (node.equals(FUNC_START_NODE)) {
                continue;
            }
            if (dependencyGraph.getDirectDependents(node).isEmpty()) {
                newGraphBuilder.addDependency(FUNC_START_NODE, node);
            }
        }

        dependencyGraph = newGraphBuilder.build();
        DotGraphSerializer dotGraphSerializer = new DotGraphSerializer();
        for (String node : dependencyGraph.getNodes()) {
            for (String directDependency : dependencyGraph.getDirectDependencies(node)) {
                dotGraphSerializer.addEdge(node, directDependency);
            }
        }

        String serializedDotGraph = dotGraphSerializer.toString();
        Path packageRootPath = ProjectPaths.packageRoot(analysisContext.currentPackage().project().sourceRoot());
        Path graphFilePath = packageRootPath.resolve(DATAFLOW_GRAPH_DOT_FILENAME);
        Files.writeString(graphFilePath, serializedDotGraph, StandardOpenOption.TRUNCATE_EXISTING);
    }

    private void addSendDependency(String fromWorker,
                                   String toWorker,
                                   DependencyGraphBuilder<String> graphBuilder) {
        String newToWorker = toWorker;
        if (FUNC_NODE.equals(toWorker)) {
            newToWorker = FUNC_END_NODE;
        }
        graphBuilder.addDependency(fromWorker, newToWorker);
    }

    private void addReceiveDependency(String fromWorker,
                                      String toWorker,
                                      DependencyGraphBuilder<String> graphBuilder) {
        String newFromWorker = fromWorker;
        if (FUNC_NODE.equals(fromWorker)) {
            newFromWorker = FUNC_START_NODE;
        }
        graphBuilder.addDependency(newFromWorker, toWorker);
    }

    private void processExpressionStmtNode(StatementNode statement,
                                           String curWorkerName,
                                           DependencyGraphBuilder<String> graphBuilder) {

        String toWorker;
        ExpressionNode expression = ((ExpressionStatementNode) statement).expression();
        if (expression.kind() == SyntaxKind.ASYNC_SEND_ACTION) {
            AsyncSendActionNode sendActionNode = (AsyncSendActionNode) expression;
            toWorker = sendActionNode.peerWorker().name().text();
        } else if (expression.kind() == SyntaxKind.SYNC_SEND_ACTION) {
            SyncSendActionNode sendActionNode = (SyncSendActionNode) expression;
            toWorker = sendActionNode.peerWorker().name().text();
        } else {
            return;
        }

        addSendDependency(curWorkerName, toWorker, graphBuilder);
    }

    private void processVarDeclarationNode(StatementNode statement,
                                           String curWorkerName,
                                           DependencyGraphBuilder<String> graphBuilder) {
        VariableDeclarationNode varDclNode = (VariableDeclarationNode) statement;
        if (varDclNode.initializer().isEmpty()) {
            return;
        }

        ReceiveActionNode receiveActionNode;
        ExpressionNode initializer = varDclNode.initializer().get();
        if (initializer.kind() == SyntaxKind.CHECK_ACTION &&
                ((CheckExpressionNode) initializer).expression().kind() == SyntaxKind.RECEIVE_ACTION) {
            CheckExpressionNode checkExpressionNode = (CheckExpressionNode) initializer;
            receiveActionNode = (ReceiveActionNode) checkExpressionNode.expression();
        } else if (initializer.kind() == SyntaxKind.RECEIVE_ACTION) {
            receiveActionNode = (ReceiveActionNode) initializer;
        } else {
            return;
        }

        Node receiveWorker = receiveActionNode.receiveWorkers();
        if (receiveWorker instanceof SimpleNameReferenceNode) {
            String fromWorker = ((SimpleNameReferenceNode) receiveWorker).name().text();
            addReceiveDependency(fromWorker, curWorkerName, graphBuilder);
        }
    }
}
