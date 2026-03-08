# Neuro-Synthetic Data Engine (Godot 4.3)

A high-fidelity Synthetic Data Generation Engine built in Godot 4.3. This project is tailored for Multimodal LLM training and Reinforcement Learning benchmarks, providing robust, vision-based cognitive agents navigating procedurally generated environments.

## Architecture

The engine adopts a decoupled simulation architecture consisting of:
- **`DataNexus.gd` (Singleton):** A centralized event logging system that captures real-time data from simulation agents, buffering it in memory and exporting it asynchronously to structured `JSON`.
- **`EnvironmentGen.gd`:** Procedurally generates a 20x20 3D arena featuring randomly styled and scaled bounding boxes representing collision obstacles, alongside dynamic Target nodes.
- **`AgentBrain.gd`:** The core AI actor. A `CharacterBody3D` featuring a 360-degree sensory array (8 discrete `RayCast3D` nodes). It operates under a rigid Cognitive State Machine (`EXPLORE`, `PURSUE`, `RECOVER`, `EVADE`) and computes complex metrics (Feature Vectors, relative targeting).
- **`UIDashboard.gd`:** A CanvasLayer HUD dynamically fetching analytics such as data row accumulation points and the runtime-averaged spatial distance to targets.

## Sim-to-Real Transfer Considerations

This framework facilitates high-quality **Sim-to-Real (S2R) transfer** by extracting clean, structured, and continuous temporal vectors:
- **Noisy Sensors:** The standard configuration provides a perfect 8-ray measurement. To support S2R domain-randomization paradigms, noise profiles (Gaussian perturbation) can easily be integrated into the Raycast detection hit ranges.
- **Explainable Decision Triggers:** Beyond raw $(x, y, z)$ position, `DataNexus` accurately logs the `Decision Trigger` ("Why the agent shifted states e.g. 'Target_Sighted'"). This rich metadata is crucial for aligning multi-modal reinforcement models and LLMs.

## Outputs & Pandas Integration

Outputs are written automatically via the `DataNexus` asynchronous thread. Data is generated in a pure, 'flattened' dictionary format where dimensional arrays like `[distance_1, distance_2...]` are exploded into explicit keys `dist_obs_0`, `dist_obs_1`. 

This guarantees **zero-friction conversion to a Pandas DataFrame**:
```python
import pandas as pd
import json

with open('user://output_data.json') as f:
    data = json.load(f)

df = pd.DataFrame(data)
print(df.head())
```

## Parallel Deployment & Headless Scalability

For high-throughput requirements in ML environments, Godot 4.3's headless mode is explicitly supported, ensuring the rendering pipeline is bypassed completely.

### Launching Headless Operations
To invoke max-velocity synthetic data generation without UI overhead constraints:

```bash
godot --headless --time-scale 10.0
```

By packaging the simulation into containers (e.g., Docker), hundreds of parallel environments can be instanced across a High-Performance Compute cluster. Because `DataNexus` isolates output to uniquely identifiable files or network streams per-instance, the merging of massive multi-scenario datasets remains trivial.
