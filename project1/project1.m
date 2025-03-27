clear all; close all;
skala = 60;             %skala czasu (wszystkie czasy w minutach) 
%gdy skala=60, to Max step size daæ 0.1
model = 'Bud3_wezel1_2010';             %WYBRAC
czas = 1000; czas_skok = 100;
kolor = 'rgbcm'; linia = ['- '; '--'; ': '];
IlePom = 3;        %ile pomieszczen
cpw = 4200;      %J/kg K, woda
row = 1000;      %kg/m3, woda
cpp = 1000;      %J/kg K,    powietrze
rop = 1.2;       %kg/m3, powietrze (+przedmioty w pomieszczeniu)
%========================================================
%=============wartosci nominalne globalne=====================
TzewN = -20;
TwewN = 20;
TopN = 70; TgpN = TopN;
TozN = 90; TgzN = TozN;
TwpN = 110; 
TwzN = 130; 
QdN = 0;
tau_siec = 120 / skala;      %opoznienia w sieci:  180 duze 10800, 120
%-----------pomieszczenia (takie same) --------------
QNJedno = 5000;    %5kW 
for i = 1:IlePom
    QN(i) = QNJedno; 
    Kg(i) = QN(i) / (TgpN-TwewN);
    Kstr(i) = QN(i) / (TwewN-TzewN);
    Vg(i) = 150/1000;      %m^3
    Vw(i) = 100 * 2.5;        %m3  
    Cg(i) = cpw*row*Vg(i)  / skala;     %zalezy od jednostki czasu
    Cp(i) = cpp*rop*Vw(i) *2 / skala;   % * korekta "na sciany"
    FgN(i) = QN(i) / (cpw*(TgzN-TgpN));
    T0_s(i) = tau_siec;
end    
FoN = sum(FgN);
%-----------wezel --------------
QwN = sum(QN);      %moc wez³a
Kco = QwN / (TwpN - TozN);
FwN = QwN / (TwzN - TwpN) / cpw;
Vw = 10/1000;                       %pojemnosc wymiennika
Cw = cpw*row*Vw  / skala;    %pojemnosc cieplna wymiennika
tau_cieplownia = 60*60 / skala;   %opoxnienie do cieplowni
KPc = 1;                                    %wl/wyl krzywe pogodowe na cieplowni (Twz = atz*Twew - btz*Tzew
atz_c = (TwzN-TzewN)/(TwewN-TzewN); btz_c = (TwzN-TwewN)/(TwewN-TzewN);
SPc0 = TwewN;
%========================================================
%============= warunki poczatkowe globalne ===================
Tzew0 = TzewN;
Twz0 = TwzN;
Fw0 = FwN*1;
Fg0 = [1, 1, 1] .* FgN;
Qd0 = [0, 0, 0];                %zawsze
%------ obliczanie zmiennych stanu ------------------
s_123 = Fg0(1) + Fg0(2) + Fg0(3);
s_23 = Fg0(2) + Fg0(3);
s_12 = Fg0(1) + Fg0(2);
A=[-Kg(1)-Kstr(1),  Kg(1),                          0,0,                                                      0,0,                                                   0, 0;
      Kg(1),             -Kg(1)-cpw*Fg0(1) ,     0,0,                                                      0,0,                                                    cpw*Fg0(1),        0;
      0,0,                                                      -Kg(2)-Kstr(2),  Kg(2),                         0,0,                                                    0, 0;    
      0,0,                                                       Kg(2),              -Kg(2)-cpw*Fg0(2),   0,0,                                                     cpw*Fg0(2),        0;
      0,0,                                                       0,0,                                                    -Kg(3)-Kstr(3),  Kg(3),                        0, 0;
      0,0,                                                       0,0,                                                     Kg(3),             -Kg(3)-cpw*Fg0(3),    cpw*Fg0(3),         0;
      0,cpw*Fg0(1),                                      0,cpw*Fg0(2),                                     0,cpw*Fg0(3),                                  -Kco-cpw*s_123,  Kco;
      0,0,                                                       0,0,                                                     0,0,                                                  +Kco                    -Kco-cpw*Fw0];
B=[Kstr(1), 0;      
      0,0;
      Kstr(2), 0;     
      0,0;
      Kstr(3), 0;     
      0,0;
      0,0;      
      0,         cpw*Fw0];
u0 = [Tzew0; Twz0];
x0 = -A^-1*B*u0;
for i = 1:3
    Twew0(i) = x0( (i-1)*2+1);
    Tgp0(i) = x0( (i-1)*2+2);
end
Toz0 = x0( IlePom*2+1);
Twp0 = x0( IlePom*2+2);
Tgp032 = (Tgp0(3)*Fg0(3) + Tgp0(2)*Fg0(2)  )   /   (  Fg0(3)+Fg0(2)    );
Tgp0321 = (Tgp0(3)*Fg0(3) + Tgp0(2)*Fg0(2)  + Tgp0(1)*Fg0(1)  )   /   (  Fg0(3) + Fg0(2) + Fg0(1)    );
%===========================================================
%model (wartosci parametrow z identyfikacji)
T = 1000; T0 = 100; k = 1 / (0.1*FwN);      %do wyznaczenia
%===========================================================
%zaklocenie
dTzew = 0;
dTwz = 0;  dSPc = 0;     %zasilanie wezla
dFw = 0 * FwN;            %przep³yw wezlowy
dFg = [0, 0, 0] .* FgN;     %procent przeplywu nominalnego danego grzejnika
dQd = [0, 0, 0] .* QN;      %procent zapotrzebowania nominalnego danego pomieszczenia

%
%symulacja
[t] = sim(model, czas);


%Rozne punkty pracy
tabTzew0 = [TzewN,  TzewN + 10,  TzewN + 10, TzewN + 10];
tabTwz0 =  [TwzN,   TwzN,        TwzN*1.5,       TwzN*1.5];
tabFw0 =   [FwN*1,  FwN*1,       FwN*1,      FwN*1.5];


%zaklocenie
dTzew = 0;
dTwz = 0;  dSPc = 0;     %zasilanie wezla
dFw = 0.1 * FwN;            %przeplyw wezlowy
dFg = [0, 0, 0] .* FgN;     %procent przeplywu nominalnego danego grzejnika
dQd = [0, 0, 0] .* QN;      %procent zapotrzebowania nominalnego danego pomieszczenia


figure(1); hold on;grid on;
figure(2); hold on;grid on; 


for ipp = 1:4
    Tzew0 = tabTzew0(ipp);
    Twz0 = tabTwz0(ipp);
    Fw0 = tabFw0(ipp);

    %------ obliczanie zmiennych stanu ------------------
    s_123 = Fg0(1) + Fg0(2) + Fg0(3);
    s_23 = Fg0(2) + Fg0(3);
    s_12 = Fg0(1) + Fg0(2);
    A=[-Kg(1)-Kstr(1),  Kg(1),                          0,0,                                                      0,0,                                                   0, 0;
          Kg(1),             -Kg(1)-cpw*Fg0(1) ,     0,0,                                                      0,0,                                                    cpw*Fg0(1),        0;
          0,0,                                                      -Kg(2)-Kstr(2),  Kg(2),                         0,0,                                                    0, 0;    
          0,0,                                                       Kg(2),              -Kg(2)-cpw*Fg0(2),   0,0,                                                     cpw*Fg0(2),        0;
          0,0,                                                       0,0,                                                    -Kg(3)-Kstr(3),  Kg(3),                        0, 0;
          0,0,                                                       0,0,                                                     Kg(3),             -Kg(3)-cpw*Fg0(3),    cpw*Fg0(3),         0;
          0,cpw*Fg0(1),                                      0,cpw*Fg0(2),                                     0,cpw*Fg0(3),                                  -Kco-cpw*s_123,  Kco;
          0,0,                                                       0,0,                                                     0,0,                                                  +Kco                    -Kco-cpw*Fw0];
    B=[Kstr(1), 0;      
          0,0;
          Kstr(2), 0;     
          0,0;
          Kstr(3), 0;     
          0,0;
          0,0;      
          0,         cpw*Fw0];
    u0 = [Tzew0; Twz0];
    x0 = -A^-1*B*u0;
    for i = 1:3
        Twew0(i) = x0( (i-1)*2+1);
        Tgp0(i) = x0( (i-1)*2+2);
    end
    Toz0 = x0( IlePom*2+1);
    Twp0 = x0( IlePom*2+2);
    Tgp032 = (Tgp0(3)*Fg0(3) + Tgp0(2)*Fg0(2)  )   /   (  Fg0(3)+Fg0(2)    );
    Tgp0321 = (Tgp0(3)*Fg0(3) + Tgp0(2)*Fg0(2)  + Tgp0(1)*Fg0(1)  )   /   (  Fg0(3) + Fg0(2) + Fg0(1)    );
    
    [t] = sim(model, czas);
    
    % Porowanie reakcji Twew - Twew0 w roznych punktach pracy
    figure(1);
    plot(t, aTwew_1 - Twew0(1), strcat(kolor(ipp),linia(1,:)));
    plot(t, aTwew_2 - Twew0(2), strcat(kolor(ipp),linia(2,:)));  
    plot(t, aTwew_3 - Twew0(3), strcat(kolor(ipp),linia(3,:)));
    
    figure(2);
    plot(t,aTop - Tgp0321, strcat(kolor(ipp),linia(1)));

    % Wykresy odpowiedzi Twew w roznych punktach pracy
    % figure(1);
    % plot(t, aTwew_1, strcat(kolor(ipp),linia(1,:)));
    % plot(t, aTwew_2, strcat(kolor(ipp),linia(2,:)));  
    % plot(t, aTwew_3, strcat(kolor(ipp),linia(3,:)));
    % 
    % figure(2);
    % plot(t,aTop, strcat(kolor(ipp),linia(1)));


end

figure(1);
title('T_w_e_w [^oC] po skoku dTzew = 10'); xlabel('t[min]'); ylabel('Twew');
legend('Punkt pracy 1 - T_w_e_w_1', 'Punkt pracy 1 - T_w_e_w_2', 'Punkt pracy 1 - T_w_e_w_3', 'Punkt pracy 2 - T_w_e_w_1', 'Punkt pracy 2 - T_w_e_w_2', 'Punkt pracy 2 - T_w_e_w_3','Punkt pracy 3 - T_w_e_w_1', 'Punkt pracy 3 - T_w_e_w_2', 'Punkt pracy 3 - T_w_e_w_3' , 'Punkt pracy 4 - T_w_e_w_1', 'Punkt pracy 4 - T_w_e_w_2', 'Punkt pracy 4 - T_w_e_w_3');

figure(2);
title('T_o_p [^oC] po skoku dTzew = 10'); xlabel('t[min]'); ylabel('Tkp');
legend('Punkt pracy 1 - T_o_p', 'Punkt pracy 2 - T_o_p', 'Punkt pracy 3 - T_o_p', 'Punkt pracy 4 - T_o_p');