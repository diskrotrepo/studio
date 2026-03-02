"""Tests for cache loading and validation."""
import pytest
import pickle
import tempfile

from midi.training import load_token_cache, CACHE_VERSION


class TestCacheValidation:
    """Tests for token cache validation."""

    def test_load_nonexistent_cache(self, tmp_path):
        """Test loading a cache that doesn't exist returns None."""
        cache_path = tmp_path / "nonexistent.pkl"
        result = load_token_cache(cache_path)
        assert result is None

    def test_load_valid_cache(self, tmp_path):
        """Test loading a valid cache file."""
        cache_path = tmp_path / "cache.pkl"

        # Create valid cache
        cache_data = {
            "sequences": [[1, 2, 3], [4, 5, 6]],
            "multitrack": False,
            "file_count": 2,
            "version": CACHE_VERSION,
        }
        with open(cache_path, "wb") as f:
            pickle.dump(cache_data, f)

        result = load_token_cache(cache_path)
        assert result is not None
        sequences, is_multitrack = result
        assert sequences == [[1, 2, 3], [4, 5, 6]]
        assert is_multitrack is False

    def test_load_multitrack_cache(self, tmp_path):
        """Test loading a multitrack cache file."""
        cache_path = tmp_path / "cache.pkl"

        # Create multitrack cache
        cache_data = {
            "sequences": [
                ([1, 2, 3], [0, 0, 1], [0, 0, 0], [0, 1, 2]),
            ],
            "multitrack": True,
            "file_count": 1,
            "version": CACHE_VERSION,
        }
        with open(cache_path, "wb") as f:
            pickle.dump(cache_data, f)

        result = load_token_cache(cache_path)
        assert result is not None
        sequences, is_multitrack = result
        assert is_multitrack is True

    def test_reject_invalid_format(self, tmp_path):
        """Test rejecting cache with invalid format (not a dict)."""
        cache_path = tmp_path / "cache.pkl"

        # Create invalid cache (list instead of dict)
        with open(cache_path, "wb") as f:
            pickle.dump([[1, 2, 3]], f)

        result = load_token_cache(cache_path)
        assert result is None

    def test_reject_missing_sequences_key(self, tmp_path):
        """Test rejecting cache missing sequences key."""
        cache_path = tmp_path / "cache.pkl"

        # Create cache without sequences
        cache_data = {
            "multitrack": False,
            "file_count": 2,
        }
        with open(cache_path, "wb") as f:
            pickle.dump(cache_data, f)

        result = load_token_cache(cache_path)
        assert result is None

    def test_reject_future_version(self, tmp_path):
        """Test rejecting cache with newer version than supported."""
        cache_path = tmp_path / "cache.pkl"

        # Create cache with future version
        cache_data = {
            "sequences": [[1, 2, 3]],
            "multitrack": False,
            "version": CACHE_VERSION + 10,  # Future version
        }
        with open(cache_path, "wb") as f:
            pickle.dump(cache_data, f)

        result = load_token_cache(cache_path)
        assert result is None

    def test_accept_older_version(self, tmp_path):
        """Test accepting cache with older/missing version (backwards compatible)."""
        cache_path = tmp_path / "cache.pkl"

        # Create cache without version (old format)
        cache_data = {
            "sequences": [[1, 2, 3]],
            "multitrack": False,
        }
        with open(cache_path, "wb") as f:
            pickle.dump(cache_data, f)

        result = load_token_cache(cache_path)
        assert result is not None

    def test_file_count_warning(self, tmp_path, capsys):
        """Test warning when file counts don't match."""
        cache_path = tmp_path / "cache.pkl"

        cache_data = {
            "sequences": [[1, 2, 3]],
            "multitrack": False,
            "file_count": 10,  # Different from actual
        }
        with open(cache_path, "wb") as f:
            pickle.dump(cache_data, f)

        # Should still load but with warning
        result = load_token_cache(cache_path, num_midi_files=5)
        assert result is not None

    def test_corrupted_pickle(self, tmp_path):
        """Test handling corrupted pickle file."""
        cache_path = tmp_path / "cache.pkl"

        # Write garbage data
        with open(cache_path, "wb") as f:
            f.write(b"not a valid pickle")

        result = load_token_cache(cache_path)
        assert result is None
