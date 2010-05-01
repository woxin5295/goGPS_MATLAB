function [A, ddc_app, ddc, ddp, A0] = input_kalman_vinc(posR, pr_Rsat, ph_Rsat, ...
         posM, pr_Msat, ph_Msat, time, sat, pivot, Eph, phase)

% SYNTAX:
%   [A, ddc_app, ddc, ddp, A0] = input_kalman_vinc(posR, pr_Rsat, ph_Rsat, ...
%   posM, pr_Msat, ph_Msat, time, sat, pivot, Eph, phase);
%
% INPUT:
%   posR = ROVER position (X,Y,Z)
%   pr_Rsat = ROVER-SATELLITE code pseudorange
%   ph_Rsat = ROVER-SATELLITE phase observations
%   posM = MASTER position (X,Y,Z)
%   pr_Msat = MASTER-SATELLITE code pseudorange
%   ph_Msat = MASTER-SATELLITE phase observations
%   time = GPS time
%   sat = configuration of visible satellites
%   pivot = pivot satellite
%   Eph = ephemerides matrix
%   phase = L1 carrier (phase=1), L2 carrier (phase=2)
%
% OUTPUT:
%   A = parameters obtained from the linearization of the observation
%       equation (projected on the constraint)
%   ddc_app = approximated code double differences
%   ddc = observed code double differences
%   ddp = observed phase double differences
%   A0 = parameters obtained from the linearization of the observation
%        equation (useful for DOP computation)
%
% DESCRIPTION:
%   This function computes the parameters needed to apply the Kalman filter.
%   Transition matrix that link state variables to GPS observations.
%   Constrained path.

%----------------------------------------------------------------------------------------------
%                           goGPS v0.1 beta
%
% Copyright (C) 2009-2010 Mirko Reguzzoni*, Eugenio Realini**
%
% * Laboratorio di Geomatica, Polo Regionale di Como, Politecnico di Milano, Italy
% ** Graduate School for Creative Cities, Osaka City University, Japan
%----------------------------------------------------------------------------------------------
%
%    This program is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    This program is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with this program.  If not, see <http://www.gnu.org/licenses/>.
%----------------------------------------------------------------------------------------------

%variable initialization
global lambda1;
global lambda2;
global X_t1_t
global ax ay az s0

%number of visible satellites
nsat = size(sat,1);

%PIVOT search
i = find(pivot == sat);

%PIVOT position (with clock error and Earth rotation corrections)
posP = sat_corr(Eph, sat(i), time, pr_Rsat(i), posR);

%computation of ROVER-PIVOT and MASTER-PIVOT approximated pseudoranges
prRP_app = sqrt(sum((posR - posP).^2));
prMP_app = sqrt(sum((posM - posP).^2));

%observed code pseudorange
prRP = pr_Rsat(i);
prMP = pr_Msat(i);

%phase observations
if (phase == 1)
    phRP = lambda1 * ph_Rsat(i);
    phMP = lambda1 * ph_Msat(i);
else
    phRP = lambda2 * ph_Rsat(i);
    phMP = lambda2 * ph_Msat(i);
end

A = [];
A0 = [];
ddc_app = [];
ddc = [];
ddp = [];

%curvilinear coordinate localization
j = find((X_t1_t(1) >= s0(1:end-1)) & (X_t1_t(1) < s0(2:end)));

%computation of all the PIVOT-SATELLITE linear combinations
for i = 1 : nsat
    if (sat(i) ~= pivot)

        %satellite position (with clock error and Earth rotation corrections)
        posS = sat_corr(Eph, sat(i), time, pr_Rsat(i), posR);

        %computation of ROVER-SATELLITE and MASTER-SATELLITE approximated pseudoranges
        prRS_app = sqrt(sum((posR - posS).^2));
        prMS_app = sqrt(sum((posM - posS).^2));

        %construction of the transition matrix (only satellite-receiver geometry)
        A0 = [A0; (((posR(1) - posS(1)) / prRS_app) - ((posR(1) - posP(1)) / prRP_app)) ...
                  (((posR(2) - posS(2)) / prRS_app) - ((posR(2) - posP(2)) / prRP_app)) ...
                  (((posR(3) - posS(3)) / prRS_app) - ((posR(3) - posP(3)) / prRP_app))];

        %construction of the transition matrix (projected on the constraint)
        A = [A; ax(j)*A0(end,1) + ay(j)*A0(end,2) + az(j)*A0(end,3)];

        %computation of the estimated code double differences
        ddc_app = [ddc_app; (prRS_app - prMS_app) - (prRP_app - prMP_app)];

        %computation of the observed code double differences
        ddc = [ddc; (pr_Rsat(i) - pr_Msat(i)) - (prRP - prMP)];

        %computation of the observed phase double differences
        if (phase == 1)
            ddp = [ddp; (lambda1 * ph_Rsat(i) - lambda1 * ph_Msat(i)) - (phRP - phMP)];
        else
            ddp = [ddp; (lambda2 * ph_Rsat(i) - lambda2 * ph_Msat(i)) - (phRP - phMP)];
        end
    end
end
