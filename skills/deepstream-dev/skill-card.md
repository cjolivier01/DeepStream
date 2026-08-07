## Description: <br>
NVIDIA DeepStream SDK development with Python pyservicemaker API for building video analytics pipelines, GStreamer-based video processing, TensorRT inference integration, object detection/tracking, and Kafka/message broker integration. <br>

This skill is ready for commercial/non-commercial use. <br>

## Owner
NVIDIA <br>

### License/Terms of Use: <br>
CC-BY-4.0 AND Apache 2.0 <br>
## Use Case: <br>
Developers and engineers building real-time video analytics pipelines using NVIDIA DeepStream SDK, including multi-stream inference, object tracking, and message broker integration on dGPU and Jetson platforms. <br>

### Deployment Geography for Use: <br>
Global <br>

## Requirements / Dependencies: <br>
**Requires API Key or External Credential:** [Not Specified] <br>
**Credential Type(s):** [None identified] <br>

Do not include secrets in prompts/logs/output; use least-privilege credentials; rotate keys as appropriate. <br>

## Known Risks and Mitigations: <br>
Risk: Review before execution as proposals could introduce incorrect or misleading guidance into skills. <br>
Mitigation: Review and scan skill before deployment. <br>

## Reference(s): <br>
- [NVIDIA DeepStream SDK](https://developer.nvidia.com/deepstream-sdk) <br>
- [gstreamer_plugins.md](references/gstreamer_plugins.md) <br>
- [service_maker_api.md](references/service_maker_api.md) <br>
- [use_cases_pipelines.md](references/use_cases_pipelines.md) <br>
- [streaming_sources.md](references/streaming_sources.md) <br>
- [kafka_messaging.md](references/kafka_messaging.md) <br>
- [best_practices.md](references/best_practices.md) <br>
- [buffer_apis.md](references/buffer_apis.md) <br>
- [nvinfer_config.md](references/nvinfer_config.md) <br>
- [tracker_config.md](references/tracker_config.md) <br>
- [troubleshooting.md](references/troubleshooting.md) <br>
- [docker_containers.md](references/docker_containers.md) <br>


## Skill Output: <br>
**Output Type(s):** [Code, Shell commands, Configuration instructions] <br>
**Output Format:** [Markdown with inline code blocks] <br>
**Output Parameters:** [1D] <br>
**Other Properties Related to Output:** [None] <br>

## Evaluation Agents Used: <br>
- Claude Code (`aws/anthropic/bedrock-claude-opus-4-8`) <br>
- Codex (`openai/openai/gpt-5.5`) <br>



## Evaluation Tasks: <br>
Evaluated against 7 tasks (7 positive) in isolated k8s-sandbox pods. <br>

## Evaluation Metrics Used: <br>
Reported benchmark dimensions: <br>
- Security: Whether the skill is safe to use — checks for unsafe operations, secret leakage, and unauthorized access. <br>
- Correctness: Whether the answer is correct against the reference answer. <br>
- Discoverability: Whether the right skill was found and executed when needed. <br>
- Effectiveness: Whether the skill helped complete the user's goal and expected workflow. <br>
- Efficiency: Whether it avoided wasted tool or skill usage. <br>

Underlying evaluation signals used in this run: <br>
- `security`: Unsafe operations, secret leakage, and unauthorized access. <br>
- `skill_execution`: Whether the expected skill was found and executed. <br>
- `skill_efficiency`: Routing quality, workspace-aware skill reads, and productive tool use. <br>
- `accuracy`: Final-answer correctness against the reference answer. <br>
- `goal_accuracy`: Whether the user's goal was achieved. <br>
- `behavior_check`: Whether the expected workflow behavior was followed. <br>



## Evaluation Results: <br>
| Measure | Claude Code (Baseline → Skill Uplift) | Codex (Baseline → Skill Uplift) |
|---|---:|---:|
| Overall | 58% → 83% (+24 points) | 62% → 78% (+16 points) |
| Security | 71% → 86% (+14 points) | 71% → 64% (-7 points) |
| Correctness | 80% → 89% (+9 points) | 86% → 89% (+3 points) |
| Discoverability | 39% → 77% (+38 points) | 42% → 67% (+25 points) |
| Effectiveness | 84% → 99% (+15 points) | 86% → 97% (+11 points) |
| Efficiency | 16% → 62% (+46 points) | 23% → 72% (+49 points) |

## Skill Version(s): <br>
1.1.1 (source: frontmatter) <br>

## Ethical Considerations: <br>
NVIDIA believes Trustworthy AI is a shared responsibility and we have established policies and practices to enable development for a wide array of AI applications. When downloaded or used in accordance with our terms of service, developers should work with their internal team to ensure this skill meets requirements for the relevant industry and use case and addresses unforeseen product misuse. <br>

(For Release on NVIDIA Platforms Only) <br>
Please report quality, risk, security vulnerabilities or NVIDIA AI Concerns [here](https://app.intigriti.com/programs/nvidia/nvidiavdp/detail). <br>
