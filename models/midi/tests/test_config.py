"""Tests for TrainingConfig dataclass."""
import json
import pytest
from pathlib import Path

from midi.training import TrainingConfig
from midi.training.config import compute_model_dims, estimate_model_memory_gb


class TestTrainingConfig:
    """Tests for TrainingConfig dataclass."""

    def test_default_values(self):
        """Test that default values are sensible."""
        config = TrainingConfig()

        # Model hyperparameters
        assert config.d_model == 512
        assert config.n_heads == 8
        assert config.n_layers == 12
        assert config.seq_length == 8192

        # Training hyperparameters
        assert config.batch_size_per_gpu == 12
        assert config.gradient_accumulation == 4
        assert config.learning_rate == 3e-4
        assert config.epochs == 20
        assert config.val_split == 0.1
        assert config.early_stopping_patience == 5

    def test_d_model_divisible_by_n_heads(self):
        """Test that d_model is divisible by n_heads."""
        config = TrainingConfig()
        assert config.d_model % config.n_heads == 0

    def test_get_learning_rate_default(self):
        """Test default learning rate."""
        config = TrainingConfig()
        lr = config.get_learning_rate()
        assert lr == 3e-4

    def test_get_learning_rate_finetune(self):
        """Test fine-tune learning rate is lower."""
        config = TrainingConfig()
        lr = config.get_learning_rate(is_finetune=True)
        assert lr == 3e-5
        assert lr < config.learning_rate

    def test_get_learning_rate_lora(self):
        """Test LoRA learning rate."""
        config = TrainingConfig()
        lr = config.get_learning_rate(is_lora=True)
        assert lr == 1e-4

    def test_get_learning_rate_lora_takes_precedence(self):
        """Test that LoRA flag takes precedence over finetune."""
        config = TrainingConfig()
        lr = config.get_learning_rate(is_lora=True, is_finetune=True)
        assert lr == config.learning_rate_lora

    def test_custom_values(self):
        """Test creating config with custom values."""
        config = TrainingConfig(
            d_model=256,
            n_heads=4,
            n_layers=6,
            batch_size_per_gpu=4,
        )
        assert config.d_model == 256
        assert config.n_heads == 4
        assert config.n_layers == 6
        assert config.batch_size_per_gpu == 4

    def test_val_split_valid_range(self):
        """Test validation split is in valid range."""
        config = TrainingConfig()
        assert 0.0 < config.val_split < 1.0

    def test_grad_clip_norm_positive(self):
        """Test gradient clipping norm is positive."""
        config = TrainingConfig()
        assert config.grad_clip_norm > 0


class TestTrainingConfigJSON:
    """Tests for JSON config file loading."""

    def test_from_json_full_config(self, tmp_path):
        """Test loading a complete config from JSON."""
        config_data = {
            "d_model": 256,
            "n_heads": 4,
            "n_layers": 6,
            "seq_length": 4096,
            "batch_size_per_gpu": 6,
            "gradient_accumulation": 8,
            "learning_rate": 3e-4,
            "learning_rate_finetune": 3e-5,
            "learning_rate_lora": 1e-4,
            "epochs": 10,
            "val_split": 0.1,
            "early_stopping_patience": 3,
            "grad_clip_norm": 0.5,
            "use_tags": False,
            "use_compile": False,
            "distributed_timeout_minutes": 60,
        }
        config_path = tmp_path / "test_config.json"
        config_path.write_text(json.dumps(config_data))

        config = TrainingConfig.from_json(str(config_path))
        assert config.d_model == 256
        assert config.n_heads == 4
        assert config.seq_length == 4096
        assert config.batch_size_per_gpu == 6
        assert config.use_compile is False
        assert config.distributed_timeout_minutes == 60

    def test_from_json_partial_config(self, tmp_path):
        """Test that missing fields use dataclass defaults."""
        config_data = {"batch_size_per_gpu": 4, "use_compile": False}
        config_path = tmp_path / "partial.json"
        config_path.write_text(json.dumps(config_data))

        config = TrainingConfig.from_json(str(config_path))
        assert config.batch_size_per_gpu == 4
        assert config.use_compile is False
        # Defaults preserved for unspecified fields
        assert config.d_model == 512
        assert config.n_heads == 8
        assert config.learning_rate == 3e-4

    def test_from_json_ignores_underscore_keys(self, tmp_path):
        """Test that metadata keys prefixed with _ are ignored."""
        config_data = {
            "_description": "Test config",
            "_hardware": "test",
            "d_model": 256,
        }
        config_path = tmp_path / "meta.json"
        config_path.write_text(json.dumps(config_data))

        config = TrainingConfig.from_json(str(config_path))
        assert config.d_model == 256

    def test_from_json_unknown_key_raises(self, tmp_path):
        """Test that unknown config keys raise TypeError."""
        config_data = {"d_model": 256, "nonexistent_field": 42}
        config_path = tmp_path / "bad.json"
        config_path.write_text(json.dumps(config_data))

        with pytest.raises(TypeError, match="Unknown config keys"):
            TrainingConfig.from_json(str(config_path))

    def test_from_json_file_not_found(self):
        """Test FileNotFoundError for missing config file."""
        with pytest.raises(FileNotFoundError):
            TrainingConfig.from_json("/nonexistent/path/config.json")

    def test_from_json_malformed_json(self, tmp_path):
        """Test JSONDecodeError for malformed JSON."""
        config_path = tmp_path / "bad.json"
        config_path.write_text("{ invalid json }")

        with pytest.raises(json.JSONDecodeError):
            TrainingConfig.from_json(str(config_path))

    def test_to_json_roundtrip(self, tmp_path):
        """Test that to_json and from_json round-trip correctly."""
        original = TrainingConfig(d_model=256, batch_size_per_gpu=4)
        config_path = tmp_path / "roundtrip.json"
        original.to_json(str(config_path))

        loaded = TrainingConfig.from_json(str(config_path))
        assert loaded.d_model == original.d_model
        assert loaded.batch_size_per_gpu == original.batch_size_per_gpu
        assert loaded.n_heads == original.n_heads  # Default preserved

    def test_preset_files_are_valid(self):
        """Test that all preset config files in configs/ are loadable."""
        configs_dir = Path(__file__).parent.parent / "configs"
        if configs_dir.exists():
            for config_file in sorted(configs_dir.glob("*.json")):
                config = TrainingConfig.from_json(str(config_file))
                # Basic sanity checks
                assert config.d_model % config.n_heads == 0
                assert config.batch_size_per_gpu > 0
                assert config.gradient_accumulation > 0
                assert 0 <= config.val_split < 1


class TestComputeModelDims:
    """Tests for compute_model_dims auto-scaling."""

    def test_small_dataset(self):
        """Test that small sample counts get the smallest model."""
        result = compute_model_dims(500)
        assert result["tier"] == "small"
        assert result["d_model"] == 256
        assert result["n_heads"] == 4
        assert result["n_layers"] == 6

    def test_medium_dataset(self):
        """Test medium tier selection."""
        result = compute_model_dims(3000)
        assert result["tier"] == "medium"
        assert result["d_model"] == 384

    def test_large_dataset(self):
        """Test large tier selection."""
        result = compute_model_dims(10000)
        assert result["tier"] == "large"
        assert result["d_model"] == 512

    def test_xlarge_dataset(self):
        """Test xlarge tier selection."""
        result = compute_model_dims(50000)
        assert result["tier"] == "xlarge"
        assert result["d_model"] == 768

    def test_backward_compatible_without_memory(self):
        """Test that calling without memory arg still works (original behavior)."""
        result = compute_model_dims(3000)
        assert result["tier"] == "medium"
        assert result["stepped_up"] is False

    def test_step_up_with_sufficient_memory(self):
        """Test that sufficient GPU memory causes a tier step-up."""
        # Medium tier (3000 samples), but with plenty of GPU memory
        result = compute_model_dims(
            3000, available_memory_gb=70.0, seq_length=8192,
            batch_size=12, vocab_size=2000,
        )
        assert result["tier"] == "large"
        assert result["d_model"] == 512
        assert result["n_heads"] == 8
        assert result["n_layers"] == 12
        assert result["stepped_up"] is True

    def test_no_step_up_with_insufficient_memory(self):
        """Test that limited GPU memory prevents step-up."""
        # Medium tier (3000 samples), but very little GPU memory
        result = compute_model_dims(
            3000, available_memory_gb=5.0, seq_length=8192,
            batch_size=12, vocab_size=2000,
        )
        assert result["tier"] == "medium"
        assert result["d_model"] == 384
        assert result["stepped_up"] is False

    def test_no_step_up_from_xlarge(self):
        """Test that xlarge (top tier) cannot step up further."""
        result = compute_model_dims(
            50000, available_memory_gb=200.0, seq_length=8192,
            batch_size=12, vocab_size=2000,
        )
        assert result["tier"] == "xlarge"
        assert result["stepped_up"] is False

    def test_d_model_divisible_by_n_heads(self):
        """Test that all tiers have d_model divisible by n_heads."""
        for samples in [100, 2000, 10000, 50000]:
            result = compute_model_dims(samples)
            assert result["d_model"] % result["n_heads"] == 0

    def test_a100_40gb_steps_up_small_to_medium(self):
        """Test A100-40GB can step up a small model to medium."""
        # 500 samples → small tier, A100 should step up to medium
        result = compute_model_dims(
            500, available_memory_gb=34.0, seq_length=8192,
            batch_size=12, vocab_size=2000,
        )
        assert result["tier"] == "medium"
        assert result["d_model"] == 384
        assert result["stepped_up"] is True


class TestEstimateModelMemory:
    """Tests for estimate_model_memory_gb."""

    def test_returns_positive(self):
        mem = estimate_model_memory_gb()
        assert mem > 0

    def test_scales_with_batch_size(self):
        mem_small = estimate_model_memory_gb(batch_size=1)
        mem_large = estimate_model_memory_gb(batch_size=16)
        assert mem_large > mem_small

    def test_scales_with_layers(self):
        mem_6 = estimate_model_memory_gb(n_layers=6)
        mem_12 = estimate_model_memory_gb(n_layers=12)
        assert mem_12 > mem_6

    def test_scales_with_d_model(self):
        mem_small = estimate_model_memory_gb(d_model=256)
        mem_large = estimate_model_memory_gb(d_model=512)
        assert mem_large > mem_small
