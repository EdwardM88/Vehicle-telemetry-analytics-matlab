function generate_report(telemetry, pdf_filename)
    import mlreportgen.dom.*

    % --- 1. Extragere KPI ---
    raportData = struct();
    raportData.TotalSamples = height(telemetry);
    raportData.Duration = seconds(telemetry.Time(end) - telemetry.Time(1));
    raportData.Date = datestr(now, 'dd-mm-yyyy HH:MM:SS');
    
    raportData.MaxSpeed = max(telemetry.Speed_OBD);
    raportData.AvgSpeed = mean(telemetry.Speed_OBD);
    raportData.MaxRPM = max(telemetry.RPM);
    raportData.AvgRPM = mean(telemetry.RPM);
    raportData.MaxGAcc = max(telemetry.G_Force_Filtered);
    raportData.MaxGBrake = min(telemetry.G_Force_Filtered);
    
    raportData.MaxOil = max(telemetry.OilTemp);
    raportData.AvgOil = mean(telemetry.OilTemp);
    raportData.MaxCoolant = max(telemetry.CoolantTemp);
    raportData.AvgCoolant = mean(telemetry.CoolantTemp);
    
    % Corectat denumirea variabilei pentru utilizarea treptelor
    raportData.GearUsage = zeros(7, 1);
    for g = 0:6
        raportData.GearUsage(g+1) = sum(telemetry.Gear == g) / raportData.TotalSamples * 100;
    end

    % --- 2. Export Figuri ---
    assets_dir = fullfile(pwd, 'report_assets');
    if ~exist(assets_dir, 'dir')
        mkdir(assets_dir);
    end
    
    % Figura 1: Dinamică
    fig1 = figure('Name', 'Report_Dynamics', 'Position', [100, 100, 1000, 600], 'Color', [1 1 1], 'Visible', 'off');
    subplot(2, 1, 1);
    yyaxis left; plot(telemetry.Time, telemetry.RPM, 'LineWidth', 1.4, 'Color', [0 0.45 0.74]); ylabel('RPM'); grid on;
    yyaxis right; plot(telemetry.Time, telemetry.Speed_OBD, 'LineWidth', 1.6, 'Color', [0.85 0.33 0.1]); ylabel('Speed (km/h)');
    title('RPM vs SPEED'); legend('Motor RPM', 'Speed', 'Location', 'northwest');
    
    subplot(2, 1, 2);
    stairs(telemetry.Time, telemetry.Gear, 'LineWidth', 2, 'Color', [0.47 0.67 0.19]);
    xlabel('Time'); ylabel('Gear'); ylim([-0.5 6.5]); yticks(0:6);
    yticklabels({'Neutral', 'Tr. 1', 'Tr. 2', 'Tr. 3', 'Tr. 4', 'Tr. 5', 'Tr. 6'}); grid on;
    title('Gear ratio');
    
    fig1_path = fullfile(assets_dir, 'vehicle_dynamics.png');
    exportgraphics(fig1, fig1_path, 'Resolution', 300);
    close(fig1);
    
    % Figura 2: Distribuție
    fig2 = figure('Name', 'Report_Transmission_Dist', 'Position', [100, 100, 1000, 450], 'Color', [1 1 1], 'Visible', 'off');
    moving_mask = (telemetry.Speed_OBD > 5) & (telemetry.RPM > 700);
    
    subplot(1, 2, 1);
    scatter(telemetry.Speed_OBD(moving_mask), telemetry.RPM(moving_mask), 15, telemetry.RawRatio(moving_mask), 'filled');
    xlabel('Speed (km/h)'); ylabel('RPM'); title('RPM vs. Speed Map'); grid on; colorbar; colormap('jet');
    
    subplot(1, 2, 2);
    histogram(telemetry.RawRatio(moving_mask), 50, 'FaceColor', [0.2 0.6 0.8], 'EdgeColor', 'k');
    xlabel('RPM / Speed'); ylabel('Frecvență'); title('Raports distribution'); grid on; xlim([0 120]);
    
    fig2_path = fullfile(assets_dir, 'gear_distribution.png');
    exportgraphics(fig2, fig2_path, 'Resolution', 300);
    close(fig2);

    % --- 3. Asamblare PDF ---
    doc = Document(pdf_filename, 'pdf');
    open(doc);
    
    title_p = Paragraph('VEHICLE TELEMETRY & GEAR ESTIMATION REPORT');
    title_p.Bold = true; title_p.FontSize = '18pt'; title_p.Color = '#1A365D'; title_p.HAlign = 'center';
    append(doc, title_p);
    
    subtitle_p = Paragraph(sprintf('Generated on: %s', raportData.Date));
    subtitle_p.FontSize = '10pt'; subtitle_p.Color = '#718096'; subtitle_p.HAlign = 'center';
    append(doc, subtitle_p);
    append(doc, Paragraph(' '));
    
    sec1 = Paragraph('1. Session Key Performance Indicators (KPIs)');
    sec1.Bold = true; sec1.FontSize = '13pt'; sec1.Color = '#2B6CB0';
    append(doc, sec1);
    
    table_data = {
        'Metric Parameter', 'Value', 'Unit';
        'Total Ingested Samples', sprintf('%d', raportData.TotalSamples), 'samples';
        'Total Session Duration', sprintf('%.2f', raportData.Duration), 's';
        'Max / Mean Road Speed', sprintf('%.1f / %.1f', raportData.MaxSpeed, raportData.AvgSpeed), 'km/h';
        'Max / Mean Engine RPM', sprintf('%d / %d', round(raportData.MaxRPM), round(raportData.AvgRPM)), 'RPM';
        'Peak Acceleration / Braking', sprintf('+%.2f / %.2f', raportData.MaxGAcc, raportData.MaxGBrake), 'G';
        'Max Coolant / Oil Temp', sprintf('%d / %d', round(raportData.MaxCoolant), round(raportData.MaxOil)), '°C'
    };
    t1 = Table(table_data); t1.Border = 'single'; t1.BorderColor = '#CBD5E0'; t1.Width = '100%';
    append(doc, t1); append(doc, Paragraph(' '));
    
    sec2 = Paragraph('2. Transmission Gear Utilization');
    sec2.Bold = true; sec2.FontSize = '13pt'; sec2.Color = '#2B6CB0';
    append(doc, sec2);
    
    gear_table_data = {'Gear State', 'Share (%)'};
    gear_labels = {'Neutral / Coasting', 'Gear 1', 'Gear 2', 'Gear 3', 'Gear 4', 'Gear 5', 'Gear 6'};
    for g = 1:7
        gear_table_data(g+1, 1) = gear_labels(g);
        gear_table_data(g+1, 2) = {sprintf('%.1f %%', raportData.GearUsage(g))};
    end
    t2 = Table(gear_table_data); t2.Border = 'single'; t2.BorderColor = '#CBD5E0'; t2.Width = '60%';
    append(doc, t2); append(doc, Paragraph(' '));
    
    sec3 = Paragraph('3. Graphical Dynamics & Signal Distributions');
    sec3.Bold = true; sec3.FontSize = '13pt'; sec3.Color = '#2B6CB0';
    append(doc, sec3);
    
    img1 = Image(fig1_path); img1.Width = '6.5in'; append(doc, img1);
    img2 = Image(fig2_path); img2.Width = '6.5in'; append(doc, img2);
    
    close(doc);
    open(pdf_filename);
end