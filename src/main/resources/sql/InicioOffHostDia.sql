USE DBTarjeta
GO

 
/* 
Nombre            :     InicioOFFHostDia 
Proposito   :     Corre el inicio de Operaciones offhost y su volcado a la base de negocio 
Creado            :      
Modificado  :     MOHE 02/11/2010 Se incremento soporte a Operaciones de Cambio de clave en offHost 
                NSSE-MOHE 16/12/2010 soporte CTS  
                CCLA 06/06/2014 se agrega parametros para registro en atmmov 
                CCLA 19/11/2014 se considera nuevo campo de ATMMov cTxnDateTime en el cursor 
				CVVV 06/03/2019 Se agrega código de Consulta de Movimientos para extracto de cuentas 
				MOHE - RTYP 30-01-2020 Se considera copecod de fast fund para el volcado 
				EZJK - HSPC 26/11/2021 Se agregan parámetros de psPOSEntryMode y psCustomerInformation para ser enviados al SP de ATM_DEPOSITO 
				EZJK 09/07/2024 Se obtiene código operación ITF para OCT y se valida transacción abierta para ROLLBACK 
				EZJK 09/07/2024 Se agregan códigos de operaciones AFT 
				EZJK 30/07/2024 Se agregan códigos de operaciones de cambio de clave OFFHOST
        PMRS YYYY/MM/DD Se agrega lógica para hacer volcado de operaciones wayki en offhost 
        definición de roswell
Ejecución	:	 
 
	declare @NroOperaciones INT , @NroOperacionesProcesadas INT 
	execute InicioOFFHostDia '20200115', @NroOperaciones out, @NroOperacionesProcesadas out 
	select  @NroOperaciones 'NroOperaciones'  , @NroOperacionesProcesadas  'NroOperacionesProcesadas' 
 
*/ 
------------------------------------------------------------------------------------------------------------------------------- 
ALTER PROCEDURE [dbo].[InicioOFFHostDia] @pdFecha DATETIME, @NroOperaciones INT output, @NroOperacionesProcesadas INT output 
AS 
--JPNZ 20081217 SE AGREGO EL CAMPO @pdFecha  
BEGIN
    -- PMRS YYYY/MM/DD Definir fecha de proceso offhost
    DECLARE @dFechaProceso DATE = @pdFecha

    -- PMRS YYYY/MM/DD Inicio se define cursor para ordenar operaciones 
    -- Ordenar operaciones wayki y unibanca por fecha real de operacion
    Select DISTINCT M.nMovNro, MAX(ATM.dFechaHora) [dFechaReal], dbo.GetFechaMovNro(M.cMovNro) Fecha, MC.cCtaCod, ATM.cTrama, 
                Sum(Case When MC.cOpeCod In ('200361','200365','200369','200391','208004','208005','208006','200379','208001',/*mohe*/'208021', 
                                           '208108','208123','208132','208140','208120','208121','208146','208116','208118','208112' -- NSSE-MOHE 16/12/2010 
										   ,'208192'--MOHE - RTYP 30-01-2020 
										   , '208276', '208282' --EZJK 09/07/2024 Se agregan códigos de operaciones AFT 
                                           ) Then nMonto Else 0 End) MontoCapital, 
                Sum(Case When MC.cOpeCod In ('200362','200366','200370','200392','208041','208042','208043','208044',/*mohe*/'208022', 
                                           '208025','208026','208027',/*mohe 02/11/2010*/ 
										   '208280', --EZJK 09/07/2024 Se agregan códigos de operaciones AFT 
										   '208104', --EZJK 30/07/2024 Se agregan códigos de operaciones de cambio de clave OFFHOST 
                                           '208109','208124','208133','208141','208101','208102','208103','208122','208113') Then nMonto Else 0 End) MontoComision, -- NSSE-MOHE 16/12/2010 
                Sum(Case When MC.cOpeCod IN ('200363','200367','200371','200393', 
                                               /*mohe*/'208023' 
											   ,'208193'--MOHE - RTYP 30-01-2020 
											   , '208278' --EZJK 09/07/2024 Se agregan códigos de operaciones AFT 
											   ) Then nMonto Else 0 End) MontoCapitalITF, 
                Sum(Case When MC.cOpeCod IN ('200364','200368','200372','200394', 
                                               /*mohe*/'208024') Then nMonto Else 0 End) MontoComisionITF,  
                --Convert(decimal(20,2),Sum(Case When MC.cOpeCod In ('200362','200366','200370','200392') Then nMonto * .007 Else 0 End)) MontoComisionITF,  
                MM.nMoneda, MM.nTipoCambio,  
                MAX(Case When MC.cOpeCod In ('200361','200365','200369','200391','208004','208005', '208006' 
                                              ,'208001','200379',      -- MOHE 28/11/2008 RETIRO POR TRANSFERENCIA POR ATM RED UNICARD 
                                              --/*mohe*/'208022') -- mohe 11/12/2009                                             
                                              /*mohe*/'208021', 
                                              '208108','208123','208132','208140','208120','208121', '208146','208118','208116','208112' -- NSSE-MOHE 16/12/2010 
											  ,'208192'--MOHE - RTYP 30-01-2020 
											  , '208276', '208282' --EZJK 09/07/2024 Se agregan códigos de operaciones AFT 
                                           ) -- mohe 11/12/2009                                           
                            Then MC.cOpeCod  
                       WHEN mc.copecod = '208022' THEN '208021' -- mohe 11/12/2009     
                       When MC.cOpeCod In ('208041','208042','208043','208044', 
                                                '208101','208102','208103','208122'  -- NSSE-MOHE 16/12/2010 
												, '208280' --EZJK 09/07/2024 Se agregan códigos de operaciones AFT 
                                           ) -- MOHE 28/11/2008 consultas                                           
                                   Then M.cOpeCod  
                              WHEN mc.copecod = '208113' THEN '208112' -- NSSE-MOHE 16/12/2010 
                       When MC.cOpeCod In ('200362','208109') -- JPNZ 20081217 
                            Then M.cOpeCod  
                       WHEN mc.copecod in ('208025','208026','208027') THEN MC.cOpeCod -- mohe 02/11/2010 
					   WHEN mc.copecod in ('208104') THEN '208108' --EZJK 30/07/2024 Se agregan códigos de operaciones de cambio de clave OFFHOST 
              Else '0'  
                  End) OperacionCapital , 
                ATM.cPan, ATM.cHora, ATM.cMesDia, 
                -- ccla 06/06/2014 
                ATM.cTrace, ATM.cPrCode, ATM.cCurCode, 
                ATM.cIssInst, ATM.cAcqInst, ATM.cPosCondCode, ATM.cCardLocation, ATM.cTxnDateTime 
       INTO #UBAMov
       from dbo.MovOffHost M  
                  Inner Join dbo.MovCapOffHost MC On M.nMovNro = MC.nMovNro 
                  Inner Join dbo.ATMMov ATM On ATM.nMovNro = M.nMovNro 
                  LEFT Join dbo.MovMonedaOFFHost MM On MM.nMovNro = M.nMovNro  
            Where M.nMovFlag = 0  
              -- AND ATM.dFechaHora >= @dFechaProceso -- PMRS YYYY/MM/DD Se debe filtrar por fecha?
            Group By M.nMovNro,dbo.GetFechaMovNro(M.cMovNro), MC.cCtaCod, ATM.cTrama, MM.nMoneda, MM.nTipoCambio, 
                      ATM.cPan, ATM.cHora, ATM.cMesDia, 
                      -- ccla 06/06/2014 
                      ATM.cTrace, ATM.cPrCode, ATM.cCurCode, 
    ATM.cIssInst, ATM.cAcqInst, ATM.cPosCondCode, ATM.cCardLocation, ATM.cTxnDateTime
    -- PMRS YYYY/MM/DD Fin se define cursor combinada para ordenar operaciones

    -- SELECT dFechaReal [dFecha], nMovNro [Identificador], 'UBA' [Canal] FROM #UBAMov
    -- -- WHERE dFechaHora >= @dFechaProceso -- AND nmovf = 0 PMRS YYYY/MM/DD Ya se aplica filtro para generar la tabla UBAMov
    -- -- ORDER BY dFechaReal
    -- UNION
    -- SELECT dFechaReal [dFecha], IDTransaccionApp [Identificador], 'WAYKI' [Canal] FROM DBTarjeta..AppMov
    --   WHERE nMovFlag = 1
    --   AND dFechaReal >= @dFechaProceso -- PMRS YYYY/MM/DD Se debe filtrar por fecha de proceso??
    -- ORDER BY dFecha

    -- DROP TABLE #UBAMov

    -- PMRS YYYY/MM/DD Definir tipo de operaciones en offhost
    DECLARE
      @cTipoUnibanca VARCHAR(3) = 'UBA'
      ,@cTipoWaykiIntra VARCHAR(50) = 'WAYKI INTRABANCARIAS'
    -- PMRS YYYY/MM/DD Definir cursor
    DECLARE curMovimientosOffHost CURSOR LOCAL FAST_FORWARD FOR

        SELECT dFechaReal [dFecha], nMovNro [Identificador], @cTipoUnibanca [TipoOperacion] FROM #UBAMov
        -- WHERE dFechaHora >= @dFechaProceso -- AND nmovf = 0 PMRS YYYY/MM/DD Ya se aplica filtro para generar la tabla UBAMov
        -- ORDER BY dFechaReal
        UNION
        SELECT AM.dFechaReal [dFecha], IDTransaccionApp [Identificador], @cTipoWaykiIntra [TipoOperacion]
        FROM DBTarjeta..AppMov AM
          INNER JOIN DBTarjeta.dbo.MovRefOffHostApp MOA ON AM.IDTransaccionApp = MOA.nIDTransaccionAPP
        WHERE nMovFlag = 1 -- PMRS YYYY/MM/DD Movimientos que faltan volcar
          -- AND dFechaReal >= @dFechaProceso -- PMRS YYYY/MM/DD Se debe filtrar por fecha de proceso??
        ORDER BY dFecha

    DECLARE @dFecha DATETIME, @nIdentificador INT, @cTipoOperacion VARCHAR(50)

    OPEN curMovimientosOffHost;

    FETCH NEXT FROM curMovimientosOffHost
    INTO @dFecha, @nIdentificador, @cTipoOperacion

    WHILE @@FETCH_STATUS = 0
    BEGIN
      IF @cTipoOperacion = @cTipoUnibanca -- PMRS YYYY/MM/DD Procesamiento de operaciones unibanca offhost
      BEGIN -- PMRS YYYY/MM/DD Inicio adecuacion volcado unibanca
        PRINT 'Lógica de unibanca'
        Declare @lnMovNro Int 
        Declare @ldFecha DateTime 
        Declare @lsCtaCod Varchar(18) 
        Declare @lsTrama  Varchar(5000) 
        Declare @lnMontoCapital Money 
        Declare @lnMontoComision Money 
        Declare @lnMontoCapitalITF Money 
        Declare @lnMontoComisionITF Money 
        Declare @lnMoneda Int 
        Declare @lnTipoCambio Money 
        Declare @lsPAN varchar(16) 
        Declare @lsHora varchar(6) 
        Declare @lsMESDIA varchar(4) 
        Declare @lsTrace varchar(6), @lsPrCode varchar(10), @lsCurCode varchar(3) 
        Declare @lsIssInst varchar(11), @lsAcqInst varchar(11), @lsPosCondCode varchar(5), @lsCardLocation varchar(40), @lsTxnDateTime varchar(10) 
        
        Declare @lsOpeCodCapital     Varchar(6) 
        Declare @lsOpeCodComision    Varchar(6) 
        Declare @lsOpeCodCapitalITF  Varchar(6) 
        Declare @lsOpeCodComisionITF Varchar(6) 
        
        Declare @aa Int  
        Declare @aaa char(5) 
        declare @psUser varchar(10) -- NSSE 27/11/2008 
        declare @S varchar(50)  -- mohe 
        declare @nTipoServicio int -- mohe


        SELECT
          @lnMovNro = nMovNro, @ldFecha = Fecha, @lsCtaCod = cCtaCod, @lsTrama = cTrama, @lnMontoCapital = MontoCapital, @lnMontoComision = MontoComision,
          @lnMontoCapitalITF = MontoCapitalITF, @lnMontoComisionITF = MontoComisionITF, @lnMoneda = nMoneda, @lnTipoCambio = nTipoCambio, @lsOpeCodCapital = OperacionCapital, @lsPAN = cPan, @lsHora = cHora, @lsMESDIA = cMesDia, @lsTrace = cTrace, @lsPrCode = cPrCode, @lsCurCode = cCurCode, @lsIssInst = cIssInst, @lsAcqInst = cAcqInst, @lsPosCondCode = cPosCondCode, @lsCardLocation = cCardLocation, @lsTxnDateTime = cTxnDateTime
        FROM #UBAMov
        WHERE nMovNro = @nIdentificador -- PMRS YYYY/MM/DD Filtrar por identificador (para unibanca es movimiento de offhost) 
  
        declare @lnResult int = 1 -- MOHE - RTYP 30-01-2020,  1: Error en volcado de una operación 
        declare @psPOSEntryMode varchar(4) -- EZJK - HSPC 26/11/2021 Se agregan parámetros de psPOSEntryMode y psCustomerInformation para ser enviados al SP de ATM_DEPOSITO 
        declare @psCustomerInformation varchar(25) -- EZJK - HSPC 26/11/2021 Se agregan parámetros de psPOSEntryMode y psCustomerInformation para ser enviados al SP de ATM_DEPOSITO 
        BEGIN -- PMRS YYYY/MM/DD Inicio procedimiento original de volcado operacion UBA
--          Set @lsOpeCodComision    = Case @lsOpeCodCapital When '200361' Then '200362' When '200365' Then '200366' When '200369' Then '200370' When '200391' Then '200392' End 
--          Set @lsOpeCodCapitalITF  = Case @lsOpeCodCapital When '200361' Then '200363' When '200365' Then '200367' When '200369' Then '200371' When '200391' Then '200393' End  
--          Set @lsOpeCodComisionITF = Case @lsOpeCodCapital When '200361' Then '200364' When '200365' Then '200368' When '200369' Then '200372' When '200391' Then '200394' End 
            Set @lsOpeCodComision    = Case @lsOpeCodCapital When '208005' Then '200362'                     
                                                                                   When '208121' Then '208109'  --CTS 
                                                                                 When '208001' Then '200362'   
                                                                                 When '208118' Then '208109'  --CTS 
                                                                                   When '208004' Then '200362'  
                                                                                   When '208120' Then '208109' --CTS 
                                                                                   When '200361' Then '200362'  
                                                                                   When '208108' Then '208109' --CTS 
                                                                                   When '200365' Then '200366'  
                                                                                   When '208123' Then '208124' --CTS 
                                                                                   When '200369' Then '200370'  
                                                                                   When '208132' Then '208133' --CTS 
                                                                                   When '200391' Then '200392'  
                                                                                   When '208140' Then '208141' --CTS 
                                                                        /*mohe*/When '208021' Then '208022'  
                                                                                    When '208112' Then '208113' --CTS 
                                                                                    When '208006' Then '200362'   
                                                       When '208146' Then '208109'  --CTS 
                                                                                   When '200379' Then '200362'  
                                                                                 When '208116' Then '208109' --CTS                           
                                      /*mohe 02/11/2010*/When '208025' Then '208025'  
                                                         When '208026' then '208026'  
                                                         When '208027' then '208027'  
														 --EZJK 09/07/2024 Se agregan códigos de operaciones AFT 
														 WHEN '208276' THEN '208280' 
														 WHEN '208282' THEN '208280' 
														 --END EZJK 09/07/2024 Se agregan códigos de operaciones AFT 
                                   End 
            Set @lsOpeCodCapitalITF  = Case @lsOpeCodCapital When '208005' Then '200363'   
                                                             When '208001' Then '200363'   
                                                             When '208004' Then '200363'  
                                                             When '200361' Then '200363'  
                                                             When '200365' Then '200367'  
                                                             When '200369' Then '200371'  
                                                             When '200391' Then '200393'  
                                                     /*mohe*/When '208021' Then '208023'  
                                                             When '208006' Then '200363'   
                                                             When '200379' Then '200363'  
                                      /*mohe 02/11/2010*/    When '208025' Then '200363'  
                                                             When '208026' Then '208023'  
                                                             When '208027' Then '208023' 
														                                 When '208192' Then '208193' --EZJK 09/07/2024 Se obtiene código operación ITF para OCT 
                                                            --EZJK 09/07/2024 Se agregan códigos de operaciones AFT 
                                                             WHEN '208276' THEN '208278' 
                                                             WHEN '208282' THEN '208278' 
                                                          --END EZJK 09/07/2024 Se agregan códigos de operaciones AFT 
                 End 
            Set @lsOpeCodComisionITF = Case @lsOpeCodCapital When '208005' Then '200364'   
                                                             When '208001' Then '200364' 
															                               When '208004' Then '200364'  
                                                             When '200361' Then '200364'  
                                                             When '200365' Then '200368'  
                                                             When '200369' Then '200372'  
                                                             When '200391' Then '200394'  
                                                     /*mohe*/When '208021' Then '208024'  
                                                             When '208006' Then '200364'   
                                                             When '200379' Then '200364'  
                                      /*mohe 02/11/2010*/    When '208025' Then '200364'  
                                                             When '208026' Then '200364'  
                                                             When '208027' Then '200364'  
                                   End    
            -- MOHE 28/11/2008 cambio de cOpeCOd para comisiones  
           -- ccla      19/11/2014 
           --select @S = dbo.fg_RecuperaValorXML(@lsTrama,'PRCODE') 
           select @S = @lsPrCode 
             --Si es consulta de cuenta 
             If Substring(@S, 1, 2) = '31' And Substring(@S, 5, 2) = '00'  
                Set @lsOpeCodComision =  CASE WHEN SUBSTRING(@lsCtaCod,6,3)<>'234' THEN '208041' ELSE '208101' END -- sOpeCodConsCuenta 
        
             --Si es consulta de Movimiento 
			  --CVVV 06/03/2019 Se agrega código de Consulta de Movimientos 
             --If Substring(@S, 1, 2) = '39' And Substring(@S, 5, 2) = '10'  
              If Substring(@S, 1, 2) = '39' And (Substring(@S, 5, 2) = '00' or Substring(@S, 5, 2) = '10') 
            Set @lsOpeCodComision =  CASE WHEN SUBSTRING(@lsCtaCod,6,3)<>'234' THEN '208042' ELSE '208102' END --sOpeCodConsMov 
              
             --Si es consulta Integrada 
             If Substring(@S, 1, 6) = '930099'  
                Set @lsOpeCodComision =  CASE WHEN SUBSTRING(@lsCtaCod,6,3)<>'234' THEN '208043' ELSE '208103' END -- sOpeCodConsIntegrada 
           
             --Si es consulta tipo cambio 
             If Substring(@S, 1, 6) = '980000'  
                Set @lsOpeCodComision =  CASE WHEN SUBSTRING(@lsCtaCod,6,3)<>'234' THEN '208044' ELSE '208122' END --sOpeCodConsTipoCambio 
            -- FIN MOHE 28/11/2008 
              -- MOHE 02/11/2010 cambio de clave 
             If @lsOpeCodComision = '208025' 
                 set @lsOpeCodCapital = '200361'  
               If @lsOpeCodComision = '208026' 
                   set @lsOpeCodCapital = '208021'  
               If @lsOpeCodComision = '208027' 
                   set @lsOpeCodCapital = '200365'  
              -- fin MMOHE 02/11/2010 
             If @lsOpeCodCapital = '0' 
              Set @lsOpeCodCapital = @lsOpeCodComision 
              select top 1 @psUser=RIGHT(cMovnro,4) from MovOffHost where nMovnro=@lnMovNro   ---- NSSE 27/11/2008 
 
			  -- EZJK - HSPC 26/11/2021 Obtener valores de parámetros de psPOSEntryMode y psCustomerInformation 
			    select top 1 @psPOSEntryMode=atr.sPOSEntryMode, @psCustomerInformation=atr.sCustomerInformation 
			    from ATMMov atmm with(nolock) 
			    inner join ATMTrama atr with(nolock) on atmm.cPan=atr.cPan collate Latin1_General_CI_AS and atmm.cTrace=atr.sIDTrama 
					  and atmm.cPrCode=atr.cPrCode and atmm.cTxnDateTime=atr.sTxnDateTime 
			    where atmm.nMovNroOffHost=@lnMovNro 
			  -- EZJK - HSPC 26/11/2021 Fin Obtener valores de parámetros de psPOSEntryMode y psCustomerInformation 
			   
          BEGIN TRY-- MOHE - RTYP 30-01-2020 
            BEGIN TRAN TR_Volcado -- MOHE - RTYP 30-01-2020 
  
              If @lsOpeCodCapital = '200379'  
                or @lsOpeCodCapital = '208192' -- MOHE - RTYP 30-01-2020 
                    
                  exec ATM_Deposito @pdFecha, @lsCtaCod, 
                              @lnMontoCapital, @lnMontoCapitalITF, @lnMontoComision, @lnMontoComisionITF,@lnMoneda,  
                              @lsOpeCodCapital, @lsOpeCodComision, @lsOpeCodCapitalITF, @lsOpeCodComisionITF, @lnTipoCambio,  
                              @lsTrama, @aa, @lnMovNro, @psUser,  
                              -- ccla 06/06/2014 se agregan nuevos parametros     
                              @lsHora, @lsMESDIA, @lsPAN,  
                              @lsTrace, @lsPrCode, @lsCurCode, 
                              @lsIssInst, @lsAcqInst, @lsPosCondCode, @lsCardLocation, @lsTxnDateTime, 
                              @psPOSEntryMode, @psCustomerInformation-- EZJK - HSPC 26/11/2021 Se agregan parámetros de psPOSEntryMode y psCustomerInformation para ser enviados al SP de ATM_DEPOSITO 
                  --exec ATM_Deposito @pdFecha, @lsCtaCod,  
                  --                @lnMontoCapital, @lnMontoCapitalITF, @lnMontoComision, @lnMontoComisionITF,@lnMoneda,  
                  --                @lsOpeCodCapital, @lsOpeCodComision, @lsOpeCodCapitalITF, @lsOpeCodComisionITF, @lnTipoCambio,  
                --                @lsTrama, @aa, @lnMovNro,  
                  --                                      @psUser -- NSSE 27/11/2008 
                  --JPNZ 20081217 SE AGREGO EL CAMPO @pdFecha  
                  /*exec ATM_Deposito @ldFecha, @lsCtaCod,  
                          @lnMontoCapital, @lnMontoCapitalITF, @lnMontoComision, @lnMontoComisionITF,@lnMoneda,  
                          @lsOpeCodCapital, @lsOpeCodComision, @lsOpeCodCapitalITF, @lsOpeCodComisionITF, @lnTipoCambio,  
                          @lsTrama, @aa, @lnMovNro,  
                                @psUser -- NSSE 27/11/2008 
                  */ 
              Else 
                  exec ATM_Retiro @pdFecha, @lsCtaCod,  
                            @lnMontoCapital, @lnMontoCapitalITF, @lnMontoComision, @lnMontoComisionITF,@lnMoneda,  
                            @lsOpeCodCapital, @lsOpeCodComision, @lsOpeCodCapitalITF, @lsOpeCodComisionITF, @lnTipoCambio,  
                            @lsTrama, @lsPAN, @lsHora,@lsMESDIA, @aa, @lnMovNro, @psUser, 
                            -- ccla 06/06/2014 se agregan nuevos parametros       
                            @lsTrace, @lsPrCode, @lsCurCode, 
                            @lsIssInst, @lsAcqInst, @lsPosCondCode, @lsCardLocation, @lsTxnDateTime 
                  --exec ATM_Retiro @pdFecha, @lsCtaCod,  
                  --                @lnMontoCapital, @lnMontoCapitalITF, @lnMontoComision, @lnMontoComisionITF,@lnMoneda,  
                  --                @lsOpeCodCapital, @lsOpeCodComision, @lsOpeCodCapitalITF, @lsOpeCodComisionITF, @lnTipoCambio,  
                  --                @lsTrama, @lsPAN, @lsHora,@lsMESDIA, @aa, @lnMovNro,  
            --                                      @psUser -- NSSE 27/11/2008 
                  --JPNZ 20081217 SE AGREGO EL CAMPO @pdFecha  
                  /*exec ATM_Retiro @ldFecha, @lsCtaCod,  
                          @lnMontoCapital, @lnMontoCapitalITF, @lnMontoComision, @lnMontoComisionITF,@lnMoneda,  
                          @lsOpeCodCapital, @lsOpeCodComision, @lsOpeCodCapitalITF, @lsOpeCodComisionITF, @lnTipoCambio,  
                          @lsTrama, @lsPAN, @lsHora,@lsMESDIA, @aa, @lnMovNro,  
                                @psUsuario -- NSSE 27/11/2008*/ 
    
              --set @aaa = str(@aa) 
              --print str(@aaa) 
              -- MOHE 09/12/2008 este cambio del flag debe hacerse solo a la operacion procesada 
                UPDATE MovOffHost  
                  SET nMovFlag=-1   
                where nMovFlag=0 and nMovNro = @lnMovNro        
              --fin MOHE 
                                        
              -- MOHE - RTYP 30-01-2020  
              IF @@ERROR <>0 OR @@ROWCOUNT < 1   
              BEGIN 
                SET @lnResult = 1--error 
                --EZJK 09/07/2024 Se valida transacción abierta para ROLLBACK 
                IF (XACT_STATE()) <> 0 
                  ROLLBACK TRAN TR_Volcado 
                --END EZJK 09/07/2024 Se valida transacción abierta para ROLLBACK 
              END  
              ELSE 
              BEGIN 
                SET @lnResult = 0--Volcado de operacion correcta 
                COMMIT TRAN TR_Volcado 
                SET @NroOperacionesProcesadas = @NroOperacionesProcesadas+1 -- mohe 26/12/2009 
              END 
              -- END MOHE - RTYP 30-01-2020  
        
        -- MOHE - RTYP 30-01-2020  
          END TRY	 
          BEGIN CATCH 
            --EZJK 09/07/2024 Se valida transacción abierta para ROLLBACK 
            IF (XACT_STATE()) <> 0 
              ROLLBACK TRAN TR_Volcado 
            --END EZJK 09/07/2024 Se valida transacción abierta para ROLLBACK 
          END CATCH 
        --END MOHE - RTYP 30-01-2020   
        END -- PMRS YYYY/MM/DD Inicio procedimiento original de volcado operacion UBA
      END -- PMRS YYYY/MM/DD Fin adecuacion volcado unibanca
      ELSE IF @cTipoOperacion = @cTipoWaykiIntra -- PMRS YYYY/MM/DD Procesamiento offhost de operaciones wayki
      BEGIN
        PRINT 'Lógica de wayki'
        -- PMRS YYYY/MM/DD Recuperar datos para el volcado
        -- Definir variables del cursor
        DECLARE
          @nNroMovOffHostAbono INT, @cCtaCodAbono VARCHAR(30), @cOpeCodAbono VARCHAR(6), @nMontoITFAbono MONEY, @nMontoComisionAbono MONEY, @nMontoComisionITFAbono MONEY, @cOpeCodITFAbono VARCHAR(6), @nIntangibleCTSAbono MONEY,
          @nNroMovOffHostCargo INT, @cCtaCodCargo VARCHAR(30), @cOpeCodCargo VARCHAR(6), @nMontoITFCargo MONEY, @nMontoComisionCargo MONEY, @nMontoComisionITFCargo MONEY, @cOpeCodITFCargo VARCHAR(6),
          @nIDTransaccionAPP INT, @nMoneda INT, @nMonto MONEY, @cUser VARCHAR(4), @dFechaReal DATETIME

        -- Definir variables de procesamiento
        DECLARE
          @nResultCargo INT, @nMovNroCargo INT--, @cMovNroCargo VARCHAR(25)
          ,@nResultAbono INT, @nMovNroAbono INT--, @cMovNroAbono VARCHAR(25)
          ,@nResult INT, @nError INT

        SELECT
          @nNroMovOffHostAbono = nOffHostMovNroAbono, @cCtaCodAbono = cCtaCodAbono, @cOpeCodAbono = cOpeCodAbono, @nMontoITFAbono = nMontoITFAbono, @nMontoComisionAbono = nMontoComisionAbono, @cOpeCodITFAbono = cOpeCodITFAbono,
          @nNroMovOffHostCargo = nOffHostMovNroCargo, @cCtaCodCargo = cCtaCodCargo, @cOpeCodCargo = cOpeCodCargo, @nMontoITFCargo = nMontoITFCargo, @nMontoComisionCargo = nMontoComisionCargo, @cOpeCodITFCargo = cOpeCodITFCargo,
          -- PMRS YYYY/MM/DD Cambiar moneda a entero
          @nIDTransaccionAPP = nIDTransaccionAPP, @nMoneda = nMoneda, @nMonto = nMonto, @cUser = cUser, @dFechaReal = MOA.dFechaReal
        FROM DBTarjeta.dbo.MovRefOffHostApp MOA WITH(NOLOCK)
        WHERE nIDTransaccionAPP = @nIdentificador -- PMRS YYYY/MM/DD Se filtra por el identificador (app movimiento para wayki)

        SET @nIntangibleCTSAbono = (SELECT nSeisSueldos FROM DBCMAC.dbo.CaptacCTS WITH(NOLOCK) WHERE cCtaCod = @cCtaCodAbono)
        SET @nIntangibleCTSAbono = ISNULL(@nIntangibleCTSAbono, 0)

        BEGIN TRY
          BEGIN TRANSACTION TR_Volcado_Operacion_Wayki

          EXEC DBTarjeta.dbo.spu_App_Volcado_CargoCuenta @cCtaCodCargo, @nMonto, @nMontoITFCargo, @nMontoComisionCargo, 0, @dFechaReal, @cOpeCodCargo, @cOpeCodITFCargo, @cUser, @nResultCargo OUTPUT, @nMovNroCargo OUTPUT

          IF @nResultCargo <> 0
          BEGIN
            SELECT @nResultCargo = CASE @nResultCargo
              WHEN 3 THEN 20 -- Estado de cuenta invalido
              WHEN 4 THEN 18 -- Sin saldo
              WHEN 20 THEN 87 -- Error en Cargo desconocido
              WHEN 21 THEN 96 -- Transferencia duplicada
              ELSE 87 -- Error en cargo conocido
            END

            SELECT @nError = 0/0
          END
          ELSE
          BEGIN
            EXEC DBTarjeta.dbo.spu_App_Volcado_AbonoCuenta @cCtaCodAbono, @nMonto, @nMontoITFAbono, @nMontoComisionAbono, 0, @dFechaReal, @cOpeCodAbono, @cOpeCodITFAbono, @cUser, @nIntangibleCTSAbono, @nResultAbono OUTPUT, @nMovNroAbono OUTPUT

            IF @nResultAbono <> 0
            BEGIN
              SELECT @nResultAbono = CASE @nResultAbono
                  WHEN 1 THEN 20
                  WHEN 2 THEN 71
                  WHEN 5 THEN 9
                ELSE 87
              END

              SELECT @nError = 0/0
            END

            -- PMRS YYYY/MM/DD Actualizar flag de volcado correcto en appmov
            UPDATE DBTarjeta.dbo.AppMov SET nMovFlag = 0, nMovNro1 = @nMovNroCargo, nMovNro2 = @nMovNroAbono WHERE IDTransaccionApp = @nIDTransaccionAPP
            -- PMRS YYYY/MM/DD Actualizar flag de volcado correcto en movoffhost
            UPDATE DBTarjeta.dbo.MovOffHost SET nMovFlag = -1 WHERE nMovNro IN (@nNroMovOffHostAbono, @nNroMovOffHostCargo)

            IF @@ERROR <> 0 OR @@ROWCOUNT < 1
            BEGIN
              SET @nResult = 91
              SELECT @nError = 0/0
            END

            COMMIT TRANSACTION TR_Volcado_Operacion_Wayki
          END
        END TRY
        BEGIN CATCH
          -- PMRS YYYY/MM/DD Que se hará en caso de errores no controlados?
          IF (XACT_STATE()) <> 0
            ROLLBACK TRANSACTION TR_Volcado_Operacion_Wayki
        END CATCH
      END

      FETCH NEXT FROM curMovimientosOffHost
      INTO @dFecha, @nIdentificador, @cTipoOperacion
    END

    DROP TABLE #UBAMov
    -- PMRS YYYY/MM/DD Fin
    -- -- PMRS YYYY/MM/DD. Fin volcado de operaciones OffHost
END 