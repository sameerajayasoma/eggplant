package io.samjs.ballerina.eggplant.plugin;

import io.ballerina.compiler.syntax.tree.*;
import io.ballerina.projects.DependencyGraph;
import io.ballerina.projects.DependencyGraph.DependencyGraphBuilder;
import io.ballerina.projects.plugins.AnalysisTask;
import io.ballerina.projects.plugins.SyntaxNodeAnalysisContext;
import io.ballerina.projects.util.ProjectPaths;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.util.StringJoiner;

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

    private String getFileNamePrefix(NamedWorkerDeclarator namedWorkerDeclarator) {
        FunctionDefinitionNode funcDefNode = (FunctionDefinitionNode) namedWorkerDeclarator.parent().parent();

        StringJoiner joiner = new StringJoiner("-");
        if (funcDefNode.parent() instanceof ServiceDeclarationNode svcDeclNode) {
            String svcName = convertNodeListToFileNamePart(svcDeclNode.absoluteResourcePath());
            if (!svcName.isEmpty()) {
                joiner.add(svcName);
            }
        }
        String funcName = funcDefNode.functionName().toSourceCode();
        joiner.add(convertToFileNamePart(funcName).trim());
        joiner.add(convertNodeListToFileNamePart(funcDefNode.relativeResourcePath()));
        return joiner.toString();
    }

    private String convertNodeListToFileNamePart(NodeList<Node> nodeList) {
        StringJoiner joiner = new StringJoiner("-");
        for (Node node : nodeList) {
            String path = node.toSourceCode().trim();
            if (path.equals("/")) {
                continue;
            }
            path = convertToFileNamePart(path);
            joiner.add(path);
        }

        return joiner.toString();
    }

    private String convertToFileNamePart(String part) {
        part = part.replace("[", "");
        part = part.replace("]", "");
        part = part.replace(" ", "");
        return part;
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

        String fileNamePrefix = getFileNamePrefix(namedWorkerDeclarator);
        String serializedDotGraph = dotGraphSerializer.toString();
        Path packageRootPath = ProjectPaths.packageRoot(analysisContext.currentPackage().project().sourceRoot());
        Path graphFilePath = packageRootPath.resolve(fileNamePrefix + "-" + DATAFLOW_GRAPH_DOT_FILENAME);
        if (!Files.exists(graphFilePath)) {
            Files.createFile(graphFilePath);
        }
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

        ExpressionNode initializer = varDclNode.initializer().get();
        if (initializer.kind() == SyntaxKind.CHECK_ACTION &&
                ((CheckExpressionNode) initializer).expression().kind() == SyntaxKind.RECEIVE_ACTION) {
            CheckExpressionNode checkExpressionNode = (CheckExpressionNode) initializer;
            processReceiveActionNode((ReceiveActionNode) checkExpressionNode.expression(),
                    curWorkerName, graphBuilder);
        } else if (initializer.kind() == SyntaxKind.RECEIVE_ACTION) {
            processReceiveActionNode((ReceiveActionNode) initializer, curWorkerName, graphBuilder);
        } else if (initializer.kind() == SyntaxKind.WAIT_ACTION) {
            processWaitActionNode((WaitActionNode) initializer, curWorkerName, graphBuilder);
        } else if (initializer.kind() == SyntaxKind.CHECK_ACTION && ((CheckExpressionNode) initializer).expression().kind() == SyntaxKind.WAIT_ACTION) {
            CheckExpressionNode checkExpressionNode = (CheckExpressionNode) initializer;
            processWaitActionNode((WaitActionNode) checkExpressionNode.expression(), curWorkerName, graphBuilder);
        }
    }

    private void processWaitActionNode(WaitActionNode waitActionNode, String curWorkerName,
                                       DependencyGraphBuilder<String> graphBuilder) {
        Node exprNode = waitActionNode.waitFutureExpr();
        if (exprNode instanceof WaitFieldsListNode waitFieldsListNode) {
            for (Node waitField : waitFieldsListNode.waitFields()) {
                if (waitField instanceof WaitFieldNode waitFieldNode) {
                    String fromWorker = waitFieldNode.waitFutureExpr().toSourceCode();
                    addReceiveDependency(fromWorker, curWorkerName, graphBuilder);
                } else if (waitField instanceof SimpleNameReferenceNode simpleNameReferenceNode) {
                    addReceiveDependency(simpleNameReferenceNode.toSourceCode(), curWorkerName, graphBuilder);
                }
            }
        } else if (exprNode instanceof BinaryExpressionNode binaryExpressionNode) {
            processWaitActionBinaryExprNode(binaryExpressionNode, curWorkerName, graphBuilder);
        }
    }

    private void processWaitActionBinaryExprNode(BinaryExpressionNode binaryExpressionNode, String curWorkerName,
                                                 DependencyGraphBuilder<String> graphBuilder) {
        if (binaryExpressionNode.lhsExpr() instanceof BinaryExpressionNode lhsBinaryExpressionNode) {
            processWaitActionBinaryExprNode(lhsBinaryExpressionNode, curWorkerName, graphBuilder);
        }

        if (binaryExpressionNode.rhsExpr() instanceof BinaryExpressionNode rhsBinaryExpressionNode) {
            processWaitActionBinaryExprNode(rhsBinaryExpressionNode, curWorkerName, graphBuilder);
        }

        if (binaryExpressionNode.lhsExpr() instanceof SimpleNameReferenceNode simpleNameReferenceNode) {
            addReceiveDependency(simpleNameReferenceNode.toSourceCode(), curWorkerName, graphBuilder);
        }

        if (binaryExpressionNode.rhsExpr() instanceof SimpleNameReferenceNode simpleNameReferenceNode) {
            addReceiveDependency(simpleNameReferenceNode.toSourceCode(), curWorkerName, graphBuilder);
        }
    }

    private void processReceiveActionNode(ReceiveActionNode receiveActionNode,
                                          String curWorkerName,
                                          DependencyGraphBuilder<String> graphBuilder) {
        Node receiveWorker = receiveActionNode.receiveWorkers();
        if (receiveWorker instanceof SimpleNameReferenceNode) {
            String fromWorker = ((SimpleNameReferenceNode) receiveWorker).name().text();
            addReceiveDependency(fromWorker, curWorkerName, graphBuilder);
        }
    }
}
