from setuptools import Distribution, find_packages, setup


class BinaryDistribution(Distribution):
    def has_ext_modules(self):
        return True


setup(
    name="pythonocc-core",
    version="7.9.3",
    description="Python wrapper for Open CASCADE Technology compiled via Docker",
    # Находим все пакеты, начиная с OCC
    packages=find_packages(include=["OCC", "OCC.*"]),
    # Явно указываем, что нужно включать скомпилированные библиотеки и исходники
    package_data={
        "OCC": ["*.so", "*.py", "*.pyi"],
        "OCC.Core": ["*.so", "*.py", "*.pyi"],
        "OCC.Display": ["*.so", "*.py", "*.pyi"],
        "OCC.Utils": ["*.so", "*.py", "*.pyi"],
    },
    distclass=BinaryDistribution,
    include_package_data=True,
    zip_safe=False,
)
