# Scripts to Patch ArduPilot&reg; for UAV Toolbox

This repository provides an automation script that applies specific modifications to the ArduPilot&reg; codebase in order to integrate a Simulink&reg;-specific library (AC_Simulink).  

This repository is designed to use alongside the UAV Toolbox Support Package for ArduPilot® Autopilots


## Prerequisites 
- A local checkout of the ArduCopter-4.6.2 or ArduPlane-4.6.2 repository (GPL v3).

### MathWorks Products (https://www.mathworks.com)

Requires MATLAB&reg; release R2025b
- [MATLAB&reg;](https://www.mathworks.com/products/matlab.html)
- [Simulink&reg;](https://www.mathworks.com/products/simulink.html)
- UAV Toolbox Support Package for ArduPilot&reg; Autopilots

## Installation
Clone this repository:

```
git clone https://github.com/mathworks-robotics/scripts-patch-ardupilot-uav-toolbox
cd scripts-patch-ardupilot-uav-toolbox
git checkout v1.0
```


## Usage


Run the automation script in MATLAB, providing the path to your local ArduPilot repository and the intended vehicle type.  
Currently, only **`Copter`** and **`Plane`** are supported as valid vehicle types.

`runArduPilotPatch(<path-to-ardupilot-repo>, 'Copter')
`

## License

The license is available in the License.txt file in this GitHub repository.

## Community Support
You can post your queries on the [MATLAB Central]() page for the support package.<!--- Link to the UAV Toolbox Support package for ArduPilot Autopilots file exchange will be added when it is created-->
You can also add your questions at [MATLAB Answers](https://www.mathworks.com/matlabcentral/answers/index).

Copyright 2025 The MathWorks, Inc.

