% Reto 3 - Algoritmo de control y cargas.
% Sistema Inteligente de Gestion Energetica - SIGE.
% Curso: Software para Ingenieria.
% Se conservan los tres vectores utilizados en el Reto 2.
% Modelo de la guia: capacidad de 100 kWh, SOC inicial de 50 %.
% Se asumen intervalos de una hora y carga/descarga sin perdidas.
% En deficit se calcula el SOC con la demanda total y luego se aplican
% las ordenes de desconexion, siguiendo la secuencia de la guia.
% La demanda original no se recalcula tras las ordenes de desconexion.
% Los estados de los servicios representan ordenes logicas de control.
% Con SOC = 0 %, ordenar escuela activa no garantiza energia disponible;
% este modelo no calcula la energia no suministrada de cada servicio.

% Limpia la ventana de comandos.
clc;

% Elimina las variables de ejecuciones anteriores.
clear;

% Cierra las figuras abiertas.
close all;

% ---------------------------------------------------------
% 1. DATOS DEL RETO 2 Y CONDICIONES INICIALES
% ---------------------------------------------------------

% Define las 24 posiciones horarias de la simulacion.
horas = 1:24;

% Define la duracion de cada intervalo, medida en horas.
delta_t = 1;

% Conserva la generacion solar original, medida en kW.
P_solar = [0 0 0 0 0 2 5 9 14 19 23 25 ...
           23 19 14 9 5 2 0 0 0 0 0 0];

% Conserva la generacion eolica original, medida en kW.
P_eolica = [8 7 9 6 8 10 12 9 11 13 10 14 ...
            12 9 11 8 10 13 15 12 10 8 7 9];

% Conserva la demanda total original, medida en kW.
P_demanda = [3 2 2 3 4 6 7 8 9 10 9 8 ...
             8 9 10 9 8 12 15 14 13 4 3 2];

% Comprueba que los tres perfiles contengan exactamente 24 valores.
assert(numel(P_solar) == 24 && numel(P_eolica) == 24 && ...
       numel(P_demanda) == 24, 'Cada vector debe tener 24 valores.');

% Suma las potencias solar y eolica, conservando la unidad kW.
P_total = P_solar + P_eolica;

% Convierte la generacion de cada intervalo a energia, medida en kWh.
E_gen = P_total * delta_t;

% Convierte la demanda de cada intervalo a energia, medida en kWh.
E_dem = P_demanda * delta_t;

% Calcula el balance de energia por intervalo, medido en kWh.
balance_energia = E_gen - E_dem;

% Define la capacidad energetica total de la bateria, medida en kWh.
Capacidad_bat = 100;

% Define el estado de carga inicial de la bateria, en porcentaje.
SOC_inicial = 50;

% Inicializa el SOC que se actualizara y conservara entre horas.
SOC = SOC_inicial;

% Reserva un vector para registrar el SOC al finalizar cada intervalo.
registro_SOC = zeros(1, 24);

% Reserva un arreglo de celdas para registrar la ruta de control por hora.
registro_ruta = cell(1, 24);

% ---------------------------------------------------------
% 2. REPORTE Y SIMULACION DEL CONTROL DURANTE 24 HORAS
% ---------------------------------------------------------

% Presenta el nombre del reporte en la ventana de comandos.
fprintf('RETO 3 - CONTROL DE LA MICRO-RED SIGE\n');

% Presenta la capacidad de la bateria y el SOC inicial.
fprintf('Capacidad: %.0f kWh | SOC inicial: %.2f %%\n\n', ...
        Capacidad_bat, SOC_inicial);

% Identifica las columnas del reporte horario.
fprintf('Hora | Balance(kWh) | SOC(%%) | Ruta       | Escuela    | Bombeo     | Alumbrado\n');

% Separa visualmente la cabecera de los resultados.
fprintf('---------------------------------------------------------------------------------------\n');

% Recorre secuencialmente las 24 horas, conservando el SOC acumulado.
for h = 1:24

    % Obtiene el balance de energia del intervalo actual, en kWh.
    balance_hora = balance_energia(h);

    % Define inicialmente la orden de activacion de la escuela.
    escuela = 'ACTIVA';

    % Define inicialmente la orden de activacion del bombeo.
    bombeo = 'ACTIVO';

    % Define inicialmente la orden de activacion del alumbrado.
    alumbrado = 'ACTIVO';

    % Distingue el abastecimiento suficiente del deficit energetico.
    if E_gen(h) >= E_dem(h)

        % Calcula el excedente; en equilibrio su valor es cero.
        excedente = E_gen(h) - E_dem(h);

        % Convierte el excedente en puntos porcentuales de carga.
        incremento_SOC = (excedente / Capacidad_bat) * 100;

        % Actualiza la bateria e impide superar el limite de 100 %.
        SOC = min(100, SOC + incremento_SOC);

        % Registra operacion nominal: los tres servicios quedan activos.
        ruta = 'NOMINAL';

    % Ejecuta el protocolo de deficit cuando la demanda supera la generacion.
    else

        % Calcula la energia faltante del intervalo, medida en kWh.
        faltante = E_dem(h) - E_gen(h);

        % Convierte el faltante en puntos porcentuales de descarga.
        decremento_SOC = (faltante / Capacidad_bat) * 100;

        % Actualiza la bateria e impide que el SOC sea inferior a 0 %.
        SOC = max(0, SOC - decremento_SOC);

        % Evalua el SOC actualizado para aplicar la ruta segura.
        if SOC > 40

            % Mantiene activos los tres servicios cuando SOC supera 40 %.
            ruta = 'SEGURA';

        % Evalua la ruta de alerta: 20 % < SOC <= 40 %.
        elseif SOC > 20

            % Identifica la operacion preventiva de la micro-red.
            ruta = 'ALERTA';

            % Suspende el servicio de menor prioridad.
            alumbrado = 'SUSPENDIDO';

        % Aplica emergencia cuando SOC es menor o igual a 20 %.
        else

            % Identifica la operacion de emergencia de la micro-red.
            ruta = 'EMERGENCIA';

            % Suspende el servicio de prioridad media.
            bombeo = 'SUSPENDIDO';

            % Mantiene suspendido el servicio de prioridad baja.
            alumbrado = 'SUSPENDIDO';

        % Finaliza la seleccion de prioridades; la escuela conserva ACTIVA.
        end

    % Finaliza la decision entre operacion nominal y deficit.
    end

    % Guarda el SOC al finalizar la hora actual.
    registro_SOC(h) = SOC;

    % Guarda la ruta de control aplicada en la hora actual.
    registro_ruta{h} = ruta;

    % Imprime balance, SOC actualizado y ordenes de los tres servicios.
    fprintf('%4d | %+12.2f | %6.2f | %-10s | %-10s | %-10s | %-10s\n', ...
            horas(h), balance_hora, SOC, ruta, escuela, bombeo, alumbrado);

% Finaliza el ciclo de simulacion de 24 horas.
end

% ---------------------------------------------------------
% 3. RESUMEN DE LA SIMULACION
% ---------------------------------------------------------

% Identifica las horas con deficit de generacion frente a la demanda.
horas_deficit = horas(balance_energia < 0);

% Identifica las horas con equilibrio entre generacion y demanda.
horas_equilibrio = horas(balance_energia == 0);

% Identifica las horas en que se aplico la ruta de alerta.
horas_alerta = horas(strcmp(registro_ruta, 'ALERTA'));

% Identifica las horas en que se aplico la ruta de emergencia.
horas_emergencia = horas(strcmp(registro_ruta, 'EMERGENCIA'));

% Separa el resumen del reporte horario.
fprintf('\nRESUMEN DE LA SIMULACION\n');

% Presenta la generacion energetica total del dia.
fprintf('Generacion total: %.2f kWh\n', sum(E_gen));

% Presenta la demanda energetica total del dia.
fprintf('Demanda total: %.2f kWh\n', sum(E_dem));

% Presenta el estado final de carga de la bateria.
fprintf('SOC final: %.2f %%\n', SOC);

% Identifica los valores de la siguiente salida por consola.
disp('Horas con deficit:');

% Presenta las horas con deficit.
disp(horas_deficit);

% Identifica los valores de la siguiente salida por consola.
disp('Horas en equilibrio:');

% Presenta las horas en equilibrio.
disp(horas_equilibrio);

% Identifica los valores de la siguiente salida por consola.
disp('Horas en alerta ([] indica que no hubo):');

% Presenta las horas en alerta, o un vector vacio si no se activo esta ruta.
disp(horas_alerta);

% Identifica los valores de la siguiente salida por consola.
disp('Horas en emergencia ([] indica que no hubo):');

% Presenta las horas en emergencia, o un vector vacio si no se activo esta ruta.
disp(horas_emergencia);

% ---------------------------------------------------------
% 4. GRAFICA COMPLEMENTARIA DEL ESTADO DE CARGA
% ---------------------------------------------------------

% Crea una figura para visualizar la evolucion del SOC.
figure;

% Incluye el SOC inicial en hora 0 y los 24 valores posteriores.
plot(0:24, [SOC_inicial registro_SOC], '-o', 'LineWidth', 2);

% Permite agregar los umbrales de control en la misma figura.
hold on;

% Representa el umbral que separa la ruta segura de la alerta.
plot([0 24], [40 40], '--', 'LineWidth', 1.5);

% Representa el umbral que separa la alerta de la emergencia.
plot([0 24], [20 20], ':', 'LineWidth', 1.5);

% Asigna un titulo descriptivo a la figura.
title('Estado de carga de la bateria durante 24 horas');

% Identifica el tiempo transcurrido en el eje horizontal.
xlabel('Tiempo (horas); hora 0 = estado inicial');

% Identifica el SOC y su unidad en el eje vertical.
ylabel('Estado de carga SOC (%)');

% Identifica la curva de la bateria y los umbrales de decision.
legend('SOC', 'Umbral de alerta: 40 %', 'Umbral de emergencia: 20 %', ...
       'Location', 'best');

% Activa la cuadricula para facilitar la lectura.
grid on;

% Limita el eje horizontal al estado inicial y las 24 horas simuladas.
xlim([0 24]);

% Deja margen sobre 100 % para mostrar con claridad la bateria llena.
ylim([0 105]);

% Muestra cada hora individualmente en el eje horizontal.
xticks(0:24);

% Finaliza la superposicion de curvas en la figura.
hold off;
