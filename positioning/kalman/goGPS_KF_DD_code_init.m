function [kalman_initialized] = goGPS_KF_DD_code_init(XR0, XM, time_rx, pr1_R, pr1_M, pr2_R, pr2_M, snr_R, snr_M, Eph, SP3_time, SP3_coor, SP3_clck, iono, phase)

% SYNTAX:
%   [kalman_initialized] = goGPS_KF_DD_code_init (XR0, XM, time_rx, pr1_R, pr1_M, pr2_R, pr2_M, snr_R, snr_M, Eph, SP3_time, SP3_coor, SP3_clck, iono, phase);
%
% INPUT:
%   XR0 = rover approximate position (X,Y,Z)
%   XM  = master position (X,Y,Z)
%   time_rx = GPS reception time
%   pr1_R = ROVER-SATELLITE code pseudorange (L1 carrier)
%   pr1_M = MASTER-SATELLITE code pseudorange (L1 carrier)
%   pr2_R = ROVER-SATELLITE code pseudorange (L2 carrier)
%   pr2_M = MASTER-SATELLITE code pseudorange (L2 carrier)
%   snr_R = ROVER-SATELLITE signal-to-noise ratio
%   snr_M = MASTER-SATELLITE signal-to-noise ratio
%   Eph = satellite ephemerides
%   SP3_time = precise ephemeris time
%   SP3_coor = precise ephemeris coordinates
%   SP3_clck = precise ephemeris clocks
%   iono = ionosphere parameters
%   phase = L1 carrier (phase=1) L2 carrier (phase=2)
%
% OUTPUT:
%   kalman_initialized = flag to determine if Kalman has been successfully initialized
%
% DESCRIPTION:
%   Code-only Kalman filter initialization.

%----------------------------------------------------------------------------------------------
%                           goGPS v0.3.1 beta
%
% Copyright (C) 2009-2012 Mirko Reguzzoni, Eugenio Realini
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

global sigmaq0
global cutoff snr_threshold cond_num_threshold o1 o2 o3

global Xhat_t_t X_t1_t T I Cee conf_sat conf_cs pivot pivot_old interval
global azR elR distR azM elM distM
global PDOP HDOP VDOP KPDOP KHDOP KVDOP

kalman_initialized = 0;

%topocentric coordinates initialization
azR = zeros(32,1);
elR = zeros(32,1);
distR = zeros(32,1);
azM = zeros(32,1);
elM = zeros(32,1);
distM = zeros(32,1);

%--------------------------------------------------------------------------------------------
% KALMAN FILTER DYNAMIC MODEL
%--------------------------------------------------------------------------------------------

%zero vector useful in matrix definitions
Z_o1_o1 = zeros(o1);

%T matrix construction - system dynamics
T0 = eye(o1) + diag(ones(o1-1,1),1)*interval;

%second degree polynomial
% T0 = [1 1; 0 1];
%third degree polynomial
% T0 = [1 1 0; 0 1 1; 0 0 1]

%system dynamics
%X(t+1)  = X(t) + Vx(t)
%Vx(t+1) = Vx(t)
%... <-- same for Y and Z

T = [T0      Z_o1_o1 Z_o1_o1;
     Z_o1_o1 T0      Z_o1_o1;
     Z_o1_o1 Z_o1_o1 T0];

%identity matrix for following computations
I = eye(o3);

%--------------------------------------------------------------------------------------------
% SATELLITE SELECTION
%--------------------------------------------------------------------------------------------

if (length(phase) == 2)
    sat = find( (pr1_R ~= 0) & (pr1_M ~= 0) & ...
                (pr2_R ~= 0) & (pr2_M ~= 0) );
else
    if (phase == 1)
        sat = find( (pr1_R ~= 0) & (pr1_M ~= 0) );
    else
        sat = find( (pr2_R ~= 0) & (pr2_M ~= 0) );
    end
end

%------------------------------------------------------------------------------------
% APPROXIMATE POSITION
%-----------------------------------------------------------------------------------

if ((sum(abs(XR0)) == 0) | isempty(XR0))
    %approximate position not available
    flag_XR = 0;
    XR0 = [];
else
    %approximate position available
    flag_XR = 1;
end

%--------------------------------------------------------------------------------------------
% KALMAN FILTER INITIAL STATE
%--------------------------------------------------------------------------------------------

%zero vector useful in matrix definitions
Z_om_1 = zeros(o1-1,1);

if (size(sat,1) >= 4)
    
    if (phase == 1)
        [XM, dtM, XS, dtS, XS_tx, VS_tx, time_tx, err_tropo_M, err_iono_M, sat_M, elM(sat_M), azM(sat_M), distM(sat_M), cov_XM, var_dtM]                             = init_positioning(time_rx, pr1_M(sat),   snr_M(sat),   Eph, SP3_time, SP3_coor, SP3_clck, iono, XM, [], [],     sat, cutoff, snr_threshold,       2, 0); %#ok<NASGU,ASGLU>
        if (length(sat_M) < 4); return; end
        [XR, dtR, XS, dtS,     ~,     ~,       ~, err_tropo_R, err_iono_R, sat_R, elR(sat_R), azR(sat_R), distR(sat_R), cov_XR, var_dtR, PDOP, HDOP, VDOP, cond_num] = init_positioning(time_rx, pr1_R(sat_M), snr_R(sat_M), Eph, SP3_time, SP3_coor, SP3_clck, iono, XR0, XS, dtS, sat_M, cutoff, snr_threshold, flag_XR, 1); %#ok<ASGLU>
    else
        [XM, dtM, XS, dtS, XS_tx, VS_tx, time_tx, err_tropo_M, err_iono_M, sat_M, elM(sat_M), azM(sat_M), distM(sat_M), cov_XM, var_dtM]                             = init_positioning(time_rx, pr2_M(sat),   snr_M(sat),   Eph, SP3_time, SP3_coor, SP3_clck, iono, XM, [], [],     sat, cutoff, snr_threshold,       2, 0); %#ok<NASGU,ASGLU>
        if (length(sat_M) < 4); return; end
        [XR, dtR, XS, dtS,     ~,     ~,       ~, err_tropo_R, err_iono_R, sat_R, elR(sat_R), azR(sat_R), distR(sat_R), cov_XR, var_dtR, PDOP, HDOP, VDOP, cond_num] = init_positioning(time_rx, pr2_R(sat_M), snr_R(sat_M), Eph, SP3_time, SP3_coor, SP3_clck, iono, XR0, XS, dtS, sat_M, cutoff, snr_threshold, flag_XR, 1); %#ok<ASGLU>
    end
    
    %keep only satellites that rover and master have in common
    [sat, iR, iM] = intersect(sat_R, sat_M);
    XS = XS(iR,:);
    if (~isempty(err_tropo_R))
        err_tropo_R = err_tropo_R(iR);
        err_iono_R  = err_iono_R (iR);
        err_tropo_M = err_tropo_M(iM);
        err_iono_M  = err_iono_M (iM);
    end
    
    %--------------------------------------------------------------------------------------------
    % SATELLITE CONFIGURATION SAVING AND PIVOT SELECTION
    %--------------------------------------------------------------------------------------------
    
    %satellite configuration
    conf_sat = zeros(32,1);
    conf_sat(sat,1) = +1;
    
    %no cycle-slips when working with code only
    conf_cs = zeros(32,1);
    
    %previous pivot
    pivot_old = 0;
    
    %current pivot
    [null_max_elR, pivot_index] = max(elR(sat)); %#ok<ASGLU>
    pivot = sat(pivot_index);
    
    %--------------------------------------------------------------------------------------------
    % LEAST SQUARES SOLUTION
    %--------------------------------------------------------------------------------------------

    %if at least 4 satellites are available after the cutoffs, and if the 
    % condition number in the least squares does not exceed the threshold
    if (size(sat,1) >= 4 & cond_num < cond_num_threshold)
        
        if (phase == 1)
            [XR, cov_XR] = LS_DD_code(XR, XS, pr1_R(sat), pr1_M(sat), snr_R(sat), snr_M(sat), elR(sat), elM(sat), distR(sat), distM(sat), err_tropo_R, err_tropo_M, err_iono_R, err_iono_M, pivot_index);
            %one iteration is performed, updating the linearization point
            %[XR, cov_XR] = LS_DD_code(XR, XS, pr1_R(sat), pr1_M(sat), snr_R(sat), snr_M(sat), elR(sat), elM(sat), distR(sat), distM(sat), err_tropo_R, err_tropo_M, err_iono_R, err_iono_M, pivot_index);
        else
            [XR, cov_XR] = LS_DD_code(XR, XS, pr2_R(sat), pr2_M(sat), snr_R(sat), snr_M(sat), elR(sat), elM(sat), distR(sat), distM(sat), err_tropo_R, err_tropo_M, err_iono_R, err_iono_M, pivot_index);
            %one iteration is performed, updating the linearization point
            %[XR, cov_XR] = LS_DD_code(XR, XS, pr2_R(sat), pr2_M(sat), snr_R(sat), snr_M(sat), elR(sat), elM(sat), distR(sat), distM(sat), err_tropo_R, err_tropo_M, err_iono_R, err_iono_M, pivot_index);
        end
    else
        return
    end
    
    if isempty(cov_XR) %if it was not possible to compute the covariance matrix
        cov_XR = sigmaq0 * eye(3);
    end
    sigma2_XR = diag(cov_XR);
    
else
    return
end

%initial state (position and velocity)
Xhat_t_t = [XR(1); Z_om_1; XR(2); Z_om_1; XR(3); Z_om_1];

%estimation at time t+1
X_t1_t = T*Xhat_t_t;

%--------------------------------------------------------------------------------------------
% INITIAL STATE COVARIANCE MATRIX
%--------------------------------------------------------------------------------------------

Cee(:,:) = zeros(o3);
Cee(1,1) = sigma2_XR(1);
Cee(o1+1,o1+1) = sigma2_XR(2);
Cee(o2+1,o2+1) = sigma2_XR(3);
Cee(2:o1,2:o1) = sigmaq0 * eye(o1-1);
Cee(o1+2:o2,o1+2:o2) = sigmaq0 * eye(o1-1);
Cee(o2+2:o3,o2+2:o3) = sigmaq0 * eye(o1-1);

%--------------------------------------------------------------------------------------------
% INITIAL KALMAN FILTER DOP
%--------------------------------------------------------------------------------------------

%covariance propagation
Cee_XYZ = Cee([1 o1+1 o2+1],[1 o1+1 o2+1]);
Cee_ENU = global2localCov(Cee_XYZ, Xhat_t_t([1 o1+1 o2+1]));

%KF DOP computation
KPDOP = sqrt(Cee_XYZ(1,1) + Cee_XYZ(2,2) + Cee_XYZ(3,3));
KHDOP = sqrt(Cee_ENU(1,1) + Cee_ENU(2,2));
KVDOP = sqrt(Cee_ENU(3,3));

kalman_initialized = 1;