# OpenSearch Benchmark Images

> **DISCLAIMER**: The images and documentation provided here are samples for educational and testing purposes only. Users must perform their own security review and due diligence before deploying any code or configurations to production environments.

This directory contains the "OpenSearch benchmark setup & monitoring.docx" document with before and after images demonstrating the performance and resilience characteristics of OpenSearch deployments. The following images should be extracted from this document:

## Performance Metrics Images

1. **CPU and Memory Utilization** - Shows CPU usage patterns during benchmark tests
2. **JVM Memory Pressure and Master JVM Memory Pressure** - Displays memory pressure metrics for JVM
3. **Indexing Latency and Search Latency** - Shows latency metrics for indexing and search operations
4. **Indexing Rate and Search Rate** - Displays throughput metrics for indexing and search operations
5. **Free Storage Space** - Shows available storage space during benchmark tests

## Resilience Test Images

6. **Cluster Green, Yellow and Red State** - Shows cluster state transitions during node failure simulation
7. **Master Reachable from Node, Nodes** - Displays node connectivity metrics during failure tests
8. **4xx and 5xx Errors** - Shows HTTP error rates during resilience tests

## How to Add Images

1. Extract the images from the "OpenSearch benchmark setup & monitoring.docx" document
2. Save them with descriptive names (e.g., `cpu-memory-utilization.png`, `jvm-memory-pressure.png`, etc.)
3. Place them in this directory
4. Update references in the main README.md file if necessary

These images provide valuable visual insights into the performance and resilience characteristics of OpenSearch deployments under various conditions.
