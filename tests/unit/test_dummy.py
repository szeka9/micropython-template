import unittest

from .utils import load_module


class DummyTest(unittest.TestCase):
    """
    Tests for your module.
    """

    @classmethod
    def setUpClass(cls):
        cls.main_module = load_module("your_package/main.py")

    def setUp(self):
        pass

    def test_main(self):
        self.assertEqual(self.main_module.main(), "OK")


if __name__ == "__main__":
    unittest.main(verbosity=2)
