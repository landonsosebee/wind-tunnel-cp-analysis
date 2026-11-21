%% Wind tunnel airfoil pressure analysis
% AE 1601, Georgia Tech, Fall 2024
%
% Reads manometer liquid heights for each pressure tap on the airfoil,
% converts them to pressure coefficient (Cp), plots Cp vs. chord position
% for each angle of attack, and integrates the pressure distribution to
% estimate the section lift coefficient (Cl).
%
% Run from this folder:  >> cp_analysis
% Requires MATLAB R2020a or newer (for exportgraphics).

clear; clc; close all;
set(groot, 'defaultAxesToolbarVisible', 'off');   % keep the axes toolbar out of exported images

%% Test conditions
rho_w   = 1000;      % kg/m^3, manometer fluid (water)
rho_air = 1.225;     % kg/m^3, sea-level standard air
g       = 9.81;      % m/s^2
in2m    = 0.0254;    % inches to meters
mph2ms  = 0.44704;   % mph to m/s

V_mph  = 70;          % freestream speed (see README note on 70 vs 75)
alphas = [5 10 15];   % alpha = 0 left out: no readings were recorded

q = 0.5 * rho_air * (V_mph * mph2ms)^2;   % dynamic pressure, Pa

%% Load data
% Build paths from where this script lives, so it runs no matter which
% folder MATLAB is currently in. The CSV can be in a "data" subfolder or
% right next to the script.
here    = fileparts(mfilename('fullpath'));
csvPath = fullfile(here, 'data', 'manometer_heights.csv');
if ~isfile(csvPath)
    csvPath = fullfile(here, 'manometer_heights.csv');
end
if ~isfile(csvPath)
    error('Could not find manometer_heights.csv in %s or its "data" subfolder.', here);
end

T  = readtable(csvPath);
up = T(strcmp(T.surface, 'upper'), :);
lo = T(strcmp(T.surface, 'lower'), :);

figDir = fullfile(here, 'figures');
if ~exist(figDir, 'dir'); mkdir(figDir); end

%% Height -> Cp
% Each tube is open to the room on one end, so the tap pressure is
%     p = p_amb - rho_w*g*h
% The tunnel pulls air from the room, so ambient is the stagnation
% pressure and the freestream static pressure is
%     p_inf = p_amb - q
% Plugging both into Cp = (p - p_inf)/q gives
%     Cp = 1 - rho_w*g*h/q
heightToCp = @(h_in) 1 - rho_w * g * (h_in * in2m) / q;

%% Loop over angles of attack
fprintf('Freestream: %.0f mph, q = %.1f Pa\n\n', V_mph, q);
fprintf('%6s %15s %8s %11s\n', 'alpha', 'min Cp (upper)', 'Cl est.', '2*pi*alpha');

colors = lines(numel(alphas));
Cl = zeros(size(alphas));
figAll = figure('Name', 'All angles');
axAll = axes(figAll); hold(axAll, 'on');

for k = 1:numel(alphas)
    a   = alphas(k);
    col = sprintf('h_alpha%d_in', a);

    cpU = heightToCp(up.(col));
    cpL = heightToCp(lo.(col));

    % --- Lift estimate ---------------------------------------------------
    % The leading-edge tap (x/c = 0) is shared by both surfaces, so add it
    % to the front of the lower surface data. Integrate (Cp_lower - Cp_upper)
    % from the leading edge to the last lower tap (x/c = 0.7).
    xL  = [0; lo.x_over_c];
    cpLfull = [cpU(1); cpL];
    xg  = linspace(0, max(lo.x_over_c), 200);
    dCp = interp1(xL, cpLfull, xg) - interp1(up.x_over_c, cpU, xg);
    Cn  = trapz(xg, dCp);          % normal force coefficient
    Cl(k) = Cn * cosd(a);          % axial force neglected

    fprintf('%5d° %15.2f %8.2f %11.2f\n', a, min(cpU), Cl(k), 2*pi*deg2rad(a));

    % --- Plot for this angle --------------------------------------------
    f = figure('Name', sprintf('alpha = %d', a));
    plot(up.x_over_c, cpU, 'o-', 'LineWidth', 1.2); hold on;
    plot(lo.x_over_c, cpL, 's--', 'LineWidth', 1.2);
    yline(0, 'Color', [0.5 0.5 0.5]);
    set(gca, 'YDir', 'reverse');   % convention: suction (negative Cp) plotted up
    xlabel('x/c'); ylabel('C_p');
    title(sprintf('Pressure distribution, \\alpha = %d° (C_l \\approx %.2f)', a, Cl(k)));
    legend('Upper surface', 'Lower surface', 'Location', 'best');
    grid on;
    exportgraphics(f, fullfile(figDir, sprintf('cp_alpha%d.png', a)), 'Resolution', 150);

    % --- Add to combined plot -------------------------------------------
    plot(axAll, up.x_over_c, cpU, 'o-',  'Color', colors(k,:), 'LineWidth', 1.2, ...
        'DisplayName', sprintf('\\alpha = %d° upper', a));
    plot(axAll, lo.x_over_c, cpL, 's--', 'Color', colors(k,:), 'LineWidth', 1.0, ...
        'DisplayName', sprintf('\\alpha = %d° lower', a));
end

%% Finish combined plot
yline(axAll, 0, 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off');
set(axAll, 'YDir', 'reverse');
xlabel(axAll, 'x/c'); ylabel(axAll, 'C_p');
title(axAll, 'Pressure distribution vs. angle of attack');
legend(axAll, 'Location', 'best', 'NumColumns', 2);
grid(axAll, 'on');
exportgraphics(figAll, fullfile(figDir, 'cp_all.png'), 'Resolution', 150);

%% Lift curve vs. thin airfoil theory
f = figure('Name', 'Lift curve');
aLine = linspace(0, 15, 50);
plot(aLine, 2*pi*deg2rad(aLine), '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.2); hold on;
plot(alphas, Cl, 'o-', 'LineWidth', 1.5);
xlabel('Angle of attack, \alpha (deg)'); ylabel('Section lift coefficient, C_l');
title('Lift curve estimate');
legend('Thin airfoil theory (2\pi\alpha)', 'Measured (integrated C_p)', 'Location', 'northwest');
grid on;
exportgraphics(f, fullfile(figDir, 'lift_curve.png'), 'Resolution', 150);

fprintf('\nFigures saved to figures/\n');
