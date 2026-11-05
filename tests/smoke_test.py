"""Smoke test for an installed pythonocc-core wheel.

Touches modelling, mesh and data exchange so that a missing bundled
library shows up as a failure. Run it through tests/check_wheel.sh.
"""

import os
import tempfile

from OCC.Core.BRepGProp import brepgprop
from OCC.Core.BRepMesh import BRepMesh_IncrementalMesh
from OCC.Core.BRepPrimAPI import BRepPrimAPI_MakeBox
from OCC.Core.GProp import GProp_GProps
from OCC.Core.IFSelect import IFSelect_RetDone
from OCC.Core.STEPControl import (
    STEPControl_AsIs,
    STEPControl_Reader,
    STEPControl_Writer,
)
from OCC.Core.TopAbs import TopAbs_FACE
from OCC.Core.TopExp import TopExp_Explorer

EXPECTED_VOLUME = 6000.0
EXPECTED_FACES = 6


def volume(shape):
    props = GProp_GProps()
    brepgprop.VolumeProperties(shape, props)
    return props.Mass()


def count_faces(shape):
    explorer = TopExp_Explorer(shape, TopAbs_FACE)
    count = 0
    while explorer.More():
        count += 1
        explorer.Next()
    return count


def step_round_trip(shape):
    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, "box.step")

        writer = STEPControl_Writer()
        writer.Transfer(shape, STEPControl_AsIs)
        assert writer.Write(path) == IFSelect_RetDone

        reader = STEPControl_Reader()
        assert reader.ReadFile(path) == IFSelect_RetDone
        reader.TransferRoots()
        return reader.OneShape()


def main():
    box = BRepPrimAPI_MakeBox(10, 20, 30).Shape()
    assert abs(volume(box) - EXPECTED_VOLUME) < 1e-6
    assert count_faces(box) == EXPECTED_FACES

    assert BRepMesh_IncrementalMesh(box, 0.5).IsDone()

    restored = step_round_trip(box)
    assert abs(volume(restored) - EXPECTED_VOLUME) < 1e-6
    assert count_faces(restored) == EXPECTED_FACES

    print("smoke test passed")


if __name__ == "__main__":
    main()
