function winder_plant_sfun(block)
%WINDER_PLANT_SFUN  Level-2 MATLAB S-function: winder/unwinder mechanics.
%
%   Continuous states: r [m], H [kg m^2/s] = J*omega, F [N]
%   Inputs:  Te [N m], vline [m/s], mode (+1 winding, -1 unwinding)
%   Outputs: F, r, J, TL, omega, vsurf, m
%
%   Dialog parameters:
%     p  = [rho w rc h E A L Jc Jm B Fmax rmax]
%     r0, H0, F0  initial states
%
%   Equations (all signs consistent with mode):
%     dr/dt = mode * h*vline / (2*pi*r)
%     dH/dt = Te - TL - B*omega,        TL = mode*F*r
%     dF/dt = mode * (E*A/L) * (omega*r - vline)
%
%   The variable-inertia effect is carried by the momentum form dH/dt:
%   d(J*omega)/dt = J*domega/dt + omega*dJ/dt, so no inertia term is treated
%   as an external load torque.

setup(block);
end

%% ----------------------------------------------------------------------
function setup(block)
block.NumInputPorts  = 3;
block.NumOutputPorts = 7;
block.SetPreCompInpPortInfoToDynamic;
block.SetPreCompOutPortInfoToDynamic;

for k = 1:3
    block.InputPort(k).Dimensions  = 1;
    block.InputPort(k).Complexity  = 'Real';
end
% Te and vline affect only derivatives; mode also sets the TL output.
block.InputPort(1).DirectFeedthrough = 0;
block.InputPort(2).DirectFeedthrough = 0;
block.InputPort(3).DirectFeedthrough = 1;

for k = 1:7
    block.OutputPort(k).Dimensions = 1;
    block.OutputPort(k).Complexity = 'Real';
end

block.NumContStates = 3;
block.NumDialogPrms = 4;       % p, r0, H0, F0
block.SampleTimes   = [0 0];   % continuous
block.SimStateCompliance = 'DefaultSimState';

block.RegBlockMethod('InitializeConditions', @InitCond);
block.RegBlockMethod('Outputs',              @Outputs);
block.RegBlockMethod('Derivatives',          @Derivatives);
end

%% ----------------------------------------------------------------------
function InitCond(block)
block.ContStates.Data = [block.DialogPrm(2).Data; ...
                         block.DialogPrm(3).Data; ...
                         block.DialogPrm(4).Data];
end

%% ----------------------------------------------------------------------
function Outputs(block)
p = block.DialogPrm(1).Data;
x = block.ContStates.Data;
r = x(1); H = x(2); F = x(3);
mode = block.InputPort(3).Data;

m     = p(1)*p(2)*pi*max(r^2 - p(3)^2, 0);
J     = p(9) + p(8) + 0.5*m*(r^2 + p(3)^2);
omega = H/J;

block.OutputPort(1).Data = F;
block.OutputPort(2).Data = r;
block.OutputPort(3).Data = J;
block.OutputPort(4).Data = mode*F*r;
block.OutputPort(5).Data = omega;
block.OutputPort(6).Data = omega*r;
block.OutputPort(7).Data = m;
end

%% ----------------------------------------------------------------------
function Derivatives(block)
p     = block.DialogPrm(1).Data;
Te    = block.InputPort(1).Data;
vline = block.InputPort(2).Data;
mode  = block.InputPort(3).Data;

x = block.ContStates.Data;
r = x(1); H = x(2); F = x(3);

m     = p(1)*p(2)*pi*max(r^2 - p(3)^2, 0);
J     = p(9) + p(8) + 0.5*m*(r^2 + p(3)^2);
omega = H/J;

drdt = mode*p(4)*vline/(2*pi*max(r, p(3)));
dHdt = Te - mode*F*r - p(10)*omega;
dFdt = mode*(p(5)*p(6)/p(7))*(omega*r - vline);

if r <= p(3)+1e-12  && drdt < 0,  drdt = 0; end
if r >= p(12)-1e-12 && drdt > 0,  drdt = 0; end
if F <= 1e-12       && dFdt < 0,  dFdt = 0; end
if F >= p(11)-1e-12 && dFdt > 0,  dFdt = 0; end

block.Derivatives.Data = [drdt; dHdt; dFdt];
end
