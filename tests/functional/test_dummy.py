"""
Functional test module.
"""

from your_package import main as package_main


def test_assert(name, actual, expected):
    print(f"Test {name}: ", end="")
    if actual == expected:
        print("Success")
    else:
        print("Fail")
        raise AssertionError(f"{actual} != {expected}")

def test_dummy():
    test_assert("main function returns \"OK\"", package_main.main(), "OK")


def main():
    test_dummy()


if __name__ == "__main__":
    main()
