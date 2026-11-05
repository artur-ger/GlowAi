# Research (offline)

Scripts for PDF pilot honesty — **not** part of the runtime app.

## `offline_mae_utci.py`

Compares MAE of stored mixed-model `predicted_sensation` vs UTCI→band baseline on pilot feedback logs.

```bash
python research/offline_mae_utci.py
python research/offline_mae_utci.py --csv research/sample_pilot_feedback.csv
python research/offline_mae_utci.py --sqlite path/to/glowai.db
```

Leave-one-user-out uses a naive mean residual bias from other users (proxy for personal uᵢ transfer).
