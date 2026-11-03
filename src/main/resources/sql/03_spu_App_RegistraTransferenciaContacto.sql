Use DBTarjeta
Go
/*
===============================================================================================================================
Nombre Procedimiento : dbo.spu_App_RegistraTransferenciaContacto
Funcionalidad        : Registra transferencias por contacto entre cuentas de la CmacCusco propias o terceros
Usuario              : DHFI
Fecha creación       : 23/06/2023
Fecha Modificacion	 : 01/08/2023 DHFI Se agrega entidad y nombre
Fecha modificación	 : 17/08/2023 DHFI- Obs de Ethical

Modo de ejecución    : 
	EXEC dbtarjeta.dbo.spu_App_RegistraTransferenciaContacto 1, '48175194','91','','APP1','70382740','106C42321000007956','106012371000081906',1,9
	select top 100 * from AppEventos order by 1 desc
=================================================================================================================================
*/ 
CREATE OR ALTER PROCEDURE [dbo].[spu_App_RegistraTransferenciaContacto]
	 @nTipoIDOrigen		INT			--Tipo de Documento del Cliente Originante Formato Caja Cusco
	,@cNroIDOrigen		VARCHAR(30)	--Nro de DNI del cliente
	,@cCanal			VARCHAR(2)	--Canal 91
	,@dFecha			DATETIME	--Fecha
	,@cUser				VARCHAR(4)	--Usuario APP1
	,@cNroIDDestino		VARCHAR(30)	--Nro DNI destino obtenida en el la consulta
	,@cCtaCodDestino	VARCHAR(50)	--Cuenta destino obtenida en la consulta cuenta contacto.
	,@cCtaCodOrigen		VARCHAR(50)	--Cuenta Origen obtenida en la consulta cuenta contacto.
	,@nMoneda			TINYINT		--Moneda de operacion 
	,@nMonto			MONEY		--Monto no Mayor a 500
	,@nOffHost			BIT = 0     --PMRS DD/MM/YYYY 
	
AS
BEGIN

	SET NOCOUNT ON
	--El procedimiento ha sido Realizado en base al spu_App_RegistraTransaccionTransferencia
	
		DECLARE  @lcMovNro VARCHAR(25)
				,@lnResultExoneraITF TINYINT
				,@lnResultITF TINYINT
				,@lnResultRetiro TINYINT		
			    ,@lnResultAbono TINYINT
			    ,@lnResultAsiento TINYINT
				,@lnMovNro INT
				,@lnMovNroAsiento INT 
				,@lnMovNroRet INT
				,@lnMovNroDep INT
				,@lnMonedaCargo TINYINT					
				,@lnMonedaAbono TINYINT
				,@lnMoneda TINYINT	
				,@lnMontoRetiro MONEY
				,@lnMontoAbono MONEY
				,@lnMontoITFRetiro MONEY
				,@lnMontoITFAbono MONEY
				,@lnTipoCambio MONEY
				,@lnTipoCambioUnica MONEY
				,@lnITF DECIMAL(18,5)
				,@lcFechaReal VARCHAR(8)
				------------------------
				,@lnMontoComisionOtraPlaza NUMERIC(15,2)
				------------------------
				,@lnUmbralLavadoActivos MONEY
				,@lcPerscodOrd VARCHAR(13)
				,@lcPerscodBen VARCHAR(13)
				------------------------
				,@lnTipoPersonaOrigen TINYINT
				,@lnPagoLote TINYINT
				-----------------------
				,@lcOpeCodCargo VARCHAR(6)
				,@lcOpeCodAbono VARCHAR(6)
				
				,@lnDepositoJuvenil TINYINT
				,@lnCuentaRecaudadora INT -- Se restringe depósitos a cuentas recaudadoras
				
				--Variables para tipo cambio
				,@ldFechaSistema datetime
				,@nTipoCambioVenta money
				,@nTipoCambioCompra money
				,@nTipoIDDestino INT
				--Variables para tipo cambio
				,@nResult INT 
				,@IDAutoriza INT
				,@cMensaje VARCHAR(100) 
				,@nSalidaValidacion INT	
				,@nResulLimite int --limite de operaciones
				,@nIdEvento INT =0
				,@nTokenSMS INT = 0 -- variable para recuperar si tiene afiliacion token SMS
				,@cNumTarjeta VARCHAR(20),
				@cCelularClienteReceptor varchar(9)	--Número de celular del Cliente Receptor
				DECLARE @cNomEntidad varchar(20)='Wayki de Caja Cusco'--01/08/2023 DHFI Se crea varible de entidad para op entre contactos Wayki 
				--Obtener el Nro de Celular de la cuenta configurada
				SELECT @cCelularClienteReceptor= right(CO.cCelularCli,9)
				FROM dbo.AppOpeConfiguracion CO WITH(NOLOCK) 
				WHERE CO.cCtaDeposito=@cCtaCodDestino

				--Si cuenta destino es infantil, juvenil, mancomuncada,indistinta
				declare  @nInfantil int = 0, @nJuvenil int = 0,@nIndistinta int = 0,@nMancomunada int = 0
				--Infantil
				IF SUBSTRING(@cCtaCodDestino,6,3)='236' set @nInfantil=1
				--Juvenil
				IF Exists(Select 1 from DBCMAC..CaptacAhorros with(nolock) where bJuvenil=1 and cCtaCod =@cCtaCodDestino) Set @nJuvenil=1
				--Indistinta
				IF Exists( Select 1 from DBCMAC..Captaciones with(nolock) where nPrdCtaTpo =2 and cCtaCod =@cCtaCodDestino) Set @nIndistinta=1
				--Mancomunada
				IF Exists(Select 1 from DBCMAC..Captaciones with(nolock) where nPrdCtaTpo =1 and cCtaCod =@cCtaCodDestino) Set @nMancomunada=1
				-- Si cuenta destino es infantil, juvenil, mancomuncada,indistinta
			--17/08/2023 DHFI- Obs de Ethical se obtiene cuenta Origen
			--Datos Persona DEstino
				SELECT top 1 @nTipoIDDestino = ID.cPersidTpo,
							@lcPerscodBen=ID.cperscod
				FROM DBCMAC..PersID ID WITH(NOLOCK)
					 INNER JOIN DBCMAC..Persona P WITH(NOLOCK) ON ID.cPersCod = P.cPersCod
				WHERE ID.cPersIDnro = @cNroIDDestino

				--Datos Persona Origen
				SELECT @lnTipoPersonaOrigen = P.nPersPersoneria,
					   @lcPerscodOrd=ID.cperscod
				FROM DBCMAC..PersID ID WITH(NOLOCK)
					 INNER JOIN DBCMAC..Persona P WITH(NOLOCK) ON ID.cPersCod = P.cPersCod
				WHERE ID.cPersIDnro = @cNroIDOrigen and ID.cPersIDTpo=@nTipoIDOrigen

				--Se obtiene Cuenta Retiro- Origen
				SELECT @cCtaCodOrigen = CO.cCtaRetiro
				FROM dbo.AppOpeConfiguracion CO WITH(NOLOCK) 
				WHERE cPersCod = @lcPerscodOrd	and bActivo=1

			--17/08/2023 DHFI- Obs de Ethical se obtiene cuenta Origen
			--Validación de cierre de día.
			-- PMRS YYYY/MM/DD Cierre diario solo debe diferenciar a donde inserta los movimientos
			DECLARE @nCierreDiario INT
			SET @nCierreDiario = @nOffHost
			-- IF @nOffHost = 0
			-- 	SELECT @nCierreDiario = ISNULL(nConsSisValor,0) FROM DBCMAC..ConstSistema WITH(NOLOCK) WHERE nConsSisCod = 400
			-- ELSE
			-- 	SET @nCierreDiario = 1
			-- SET @nCierreDiario = 1 -- PMRS YYYY/MM/DD Forzar offhost
			-- IF @nCierreDiario = 0
			-- PMRS YYYY/MM/DD Se mueve logica de offhost luego de las validaciones
			-- BEGIN 
			
			-- PMRS YYYY/MM/DD Se comenta ejecución de sp
			-- EXEC dbo.spu_App_ValidaPiloto @cCtaCodOrigen, 0, @nSalidaValidacion out		
			-- IF @nSalidaValidacion = 0					
			BEGIN
					
				SET @nResult = -1		
				SET @cMensaje = 'CORRECTO'
				SET @IDAutoriza = 0
				SET @lcMovNro = CONVERT(VARCHAR(8),@dFecha,112) + REPLACE(CONVERT(VARCHAR(10),GETDATE(),108),':','') + '1060100' + @cUser
				SET @lcFechaReal = CONVERT(VARCHAR(8), GETDATE(),112)		
				SET @lnMoneda = @nMoneda 
				SET @lnPagoLote = 0

				Select @ldFechaSistema=convert(datetime,right(nConsSisValor,4)+'/'+substring(nConsSisValor,4,2)+'/'+left(nConsSisValor,2))
									from DBCMAC..constsistema with(nolock) where nConsSisCod = 15
				/* --17/08/2023 DHFI- Se reubica obtencion de Datos
				--Datos Persona DEstino
				SELECT top 1 @nTipoIDDestino = ID.cPersidTpo,
							@lcPerscodBen=ID.cperscod
				FROM DBCMAC..PersID ID WITH(NOLOCK)
					 INNER JOIN DBCMAC..Persona P WITH(NOLOCK) ON ID.cPersCod = P.cPersCod
				WHERE ID.cPersIDnro = @cNroIDDestino

				--Datos Persona Origen
				SELECT @lnTipoPersonaOrigen = P.nPersPersoneria,
					   @lcPerscodOrd=ID.cperscod
				FROM DBCMAC..PersID ID WITH(NOLOCK)
					 INNER JOIN DBCMAC..Persona P WITH(NOLOCK) ON ID.cPersCod = P.cPersCod
				WHERE ID.cPersIDnro = @cNroIDOrigen and ID.cPersIDTpo=@nTipoIDOrigen
				*/--17/08/2023 DHFI- Se reubica obtencion de Datos
				-- SETEO DE VARIABLES PARA LAVADO DE ACTIVOS	
				SELECT @lnUmbralLavadoActivos = nMontoCCE	-- se considera umbral para canales electronicos
				FROM DBCMAC..EvaluacionMovLavAgencia WITH(NOLOCK)
				WHERE cAgeCod='01'						
			
				select @lnTipoCambioUnica = nValOpeUnica 
				from DBCMAC..tipocambio WITH(NOLOCK)
				where dFecCamb >=@ldFechaSistema and dFecCamb < @ldFechaSistema + 1 
			
				set @lnTipoCambioUnica = ISNULL(@lnTipoCambioUnica, 0)
			
				select @lnDepositoJuvenil = case when (bJuvenil  is null or bJuvenil = 0) then 0 else 1 end
				from dbCmac..CaptacAhorros with(nolock)
				where cCtaCod = @cCtaCodOrigen

				--Se restringe depósitos a cuentas recaudadoras
				select @lnCuentaRecaudadora = case when (bRecaudadora  is null or bRecaudadora = 0) then 0 else 1 end
				from dbCmac..CaptacAhorros with(nolock)
				where cCtaCod = @cCtaCodDestino
				--Se restringe depósitos a cuentas recaudadoras

				--definir transferencias propias o a terceros
				DECLARE @cAppTipoTransferencia VARCHAR(4)
				SET @cAppTipoTransferencia = 'TTxC'
				IF @cNroIDOrigen = @cNroIDDestino 
					SET @cAppTipoTransferencia = 'TPxC'

				--EVENTOS
				INSERT INTO AppEventos VALUES (0,@cAppTipoTransferencia,'Transferencia', GETDATE(),@ldFechaSistema,@cCtaCodOrigen,@cCtaCodDestino,0,'Solicitud de Transferencia')
				SET @nIdEvento = @@IDENTITY
				--EVENTOS

				--Se valida Horarios de pago
				DECLARE @dhoraOperacion TIME
				SET @dhoraOperacion = CONVERT (TIME, GETDATE())
																						
				DECLARE @dHorarioInicio varchar(10)
				DECLARE @dHorarioFin varchar(10)
																						
				SELECT @dHorarioInicio = dHoraIni, @dHorarioFin = dHoraFin FROM AppHorarios WITH(NOLOCK) WHERE cCodOperacion = 'TXC'
				-- Se valida Horarios de pago

				--Recupera ntoken sms y numero de tarjeta
				SELECT @nTokenSMS = TC.nAfiliacion,
						@cNumTarjeta = T.cNumTarjeta
				FROM LlavesUsuario TC with(nolock)				
						INNER JOIN Tarjeta T with(nolock) on T.cPersCod collate SQL_Latin1_General_CP1_CI_AS = TC.cPersCod and T.nCondicion = 1
						INNER JOIN DBCMAC..PersID P with(nolock) on T.cPersCod = P.cPersCod	
				WHERE P.cPersIDnro = @cNroIDOrigen and P.cPersIDTpo = @nTipoIDOrigen and T.nCondicion = 1 
								and TC.nAfiliacion = 1
				SET @nTokenSMS = ISNULL(@nTokenSMS, 0)
				SET @cNumTarjeta = ISNULL(@cNumTarjeta, '')

				if @nTokenSMS <> 1
					SET @nResult = 94 --no tiene token app
				--Recupera ntoken sms y numero de tarjeta

				--Se agrega validacion para monto min PFF
				Declare @nMontoMinPFF money 
				Select @nMontoMinPFF=nValor from APPParametros With(Nolock) Where nCodLimite=60 and cCodOperacion='T'

				Select	  @nTipoCambioVenta=nValVent
						, @nTipoCambioCompra=nValComp				
				from DBCMAC..TipoCambio with(nolock)
				Where dFecCamb >=@ldFechaSistema and dFecCamb < @ldFechaSistema + 1
								
				set @lnMonedaCargo = SUBSTRING(@cCtaCodOrigen,9,1)
				set @lnMonedaAbono = SUBSTRING(@cCtaCodDestino,9,1)

				if (@lnMonedaCargo<>@lnMonedaAbono)
				begin
					if @lnMonedaAbono = 1
						set @lnTipoCambio = @nTipoCambioCompra
					else 
						set @lnTipoCambio = @nTipoCambioVenta
				end
				-- END Obtener tipo cambio	
				IF @lnMonedaCargo = @lnMonedaAbono		-- tranferencia misma moneda
				BEGIN
					--print 'Entra a operacion normal'
					SET @lnMontoAbono = @nMonto
					SET @lnMontoRetiro = @nMonto
				END
				ELSE	-- tranferencia intermoneda
				BEGIN								
					SET @lnMontoRetiro = @nMonto
					IF @lnMoneda = 1		-- de soles a dolares
						SET @lnMontoAbono = round(@nMonto/@lnTipoCambio, 2)		  -- CAMBIO DE SOLES A DOLARES
					ELSE					-- de dolares a soles
						SET @lnMontoAbono = round(@nMonto*@lnTipoCambio, 2)   -- CAMBIO DE DOLARES A SOLES
				END

				--Obtener tipo sub producto
				Declare @ntipoPlazoFijo int = -1
				Select @ntipoPlazoFijo=nSubProducto from DBCMAC..captacplazofijo With(Nolock) Where cCtacod=@cCtaCodDestino

				--Se agrega validacion para monto min PFF
				
				BEGIN TRY 
				--Se permite solo monto min S/50 si es PFF flexible
				IF(@lcPerscodOrd = @lcPerscodBen)
				BEGIN
					SET @nResult = 1023 --No hay transferencia a mismo cliente
				END
				ELSE
				BEGIN
					IF(@lnMonedaCargo <> @lnMonedaAbono) --Solo Misma Moneda
					BEGIN
						SET @nResult = 1024 --No hay transferencias por contacto distina moneda
					END
					ELSE
					BEGIN
						-- ============== VALIDACIONES PREVIAS ================
						--VERIFICAR EXISTENCIA DE CUENTAS (ORIGEN Y DESTINO)
						IF NOT EXISTS(SELECT 1 FROM DBCMAC..Producto with(nolock) WHERE cCtaCod = @cCtaCodOrigen)
						BEGIN
							SET @nResult = 11 -- CUenta Origen no Existe
						END
						ELSE
						BEGIN 
							IF NOT EXISTS(SELECT 1 FROM DBCMAC..Producto with(nolock) WHERE cCtaCod = @cCtaCodDestino)
							BEGIN
								SET @nResult = 31 -- CUenta Destino no Existe
							END
							ELSE
							BEGIN
								--VERIFICAR EXISTENCIA DE Personas (ORIGEN Y DESTINO)
								IF NOT EXISTS(SELECT 1 FROM DBCMAC..PersID WITH(NOLOCK)WHERE cPersIDnro = @cNroIDOrigen AND cPersIDTpo = CONVERT(VARCHAR(2),@nTipoIDOrigen))
								BEGIN
									SET @nResult = 80 -- No existe Titular de Operacion
								END
								ELSE
								BEGIN
									IF NOT EXISTS(SELECT 1 FROM DBCMAC..PersID WITH(NOLOCK)WHERE cPersIDnro = @cNroIDDestino AND cPersIDTpo = CONVERT(VARCHAR(2),@nTipoIDDestino))
									BEGIN
										SET @nResult = 37 -- No existe Persona de Destino 
									END
									--VERIFICAR PERTENENCIA DE CUENTAS CON PERSONAS (ORIGEN Y DESTINO) 	
									ELSE
									BEGIN
										IF NOT EXISTS(SELECT 1 FROM DBCMAC..PersID ID WITH(NOLOCK)
														INNER JOIN DBCMAC..ProductoPersona PP WITH(NOLOCK) ON ID.cPersCod =PP.cPersCod AND ID.cPersIDnro = @cNroIDOrigen 
																   AND ID.cPersIDTpo = CONVERT(VARCHAR(2),@nTipoIDOrigen) AND PP.nPrdPersRelac IN(10)
																   AND PP.cCtaCod = @cCtaCodOrigen 
													  )
										BEGIN
											SET @nResult = 12 -- Cta. Cargo no pertenece a persona
										END
										ELSE
										BEGIN	
											IF NOT EXISTS(SELECT 1 FROM DBCMAC..PersID ID WITH(NOLOCK)
															INNER JOIN DBCMAC..ProductoPersona PP WITH(NOLOCK) ON ID.cPersCod =PP.cPersCod AND ID.cPersIDnro = @cNroIDDestino 
																	   AND ID.cPersIDTpo = CONVERT(VARCHAR(2),@nTipoIDDestino) AND PP.nPrdPersRelac IN(10)
																	   AND PP.cCtaCod = @cCtaCodDestino
														)
											BEGIN
												SET @nResult = 38 -- Cta. Abono no pertenece a persona
											END
											
											-- VERIFICAR ESTADO DE CUENTAS (ORIGEN Y DESTINO)
											ELSE
											BEGIN
												DECLARE @nPrdEstadoOrigen int, @nPrdEstadoDestino int
												Select @nPrdEstadoOrigen=nPrdEstado from DBCMAC.dbo.Producto WITH(NOLOCK) WHERE cCtaCod=@cCtaCodOrigen
												Select @nPrdEstadoDestino=nPrdEstado from DBCMAC.dbo.Producto WITH(NOLOCK) WHERE cCtaCod=@cCtaCodDestino

												IF @nPrdEstadoOrigen IN (1100)
												BEGIN
													SET @nResult = 14  -- Cuenta origen con bloqueo Total
												END
												ELSE
												BEGIN
													IF @nPrdEstadoOrigen IN(1200)
													begin
														SET @nResult = 15  -- Cuenta origen con bloqueo Retiro
													END
													ELSE
													BEGIN
														IF @nPrdEstadoOrigen IN(1300,1400)
														BEGIN
															SET @nResult = 16  -- Cuenta origen Cancelada y/o Anulada
														END
														ELSE
														BEGIN
															IF EXISTS(SELECT 1 FROM DBCMAC..Captaciones with(nolock) WHERE cCtaCod = @cCtaCodOrigen AND nPrdCtaTpo = 1 AND @lnTipoPersonaOrigen=1)
															BEGIN
																SET @nResult = 17  -- Cuenta origen Mancomunada
															END
															ELSE
															BEGIN																		
																IF @nPrdEstadoDestino = 1100
																BEGIN
																	SET @nResult = 32  -- Cta Destino con bloqueo total	
																END
																ELSE	
																BEGIN
																	IF @nPrdEstadoDestino IN(1300,1400)
																	BEGIN
																		SET @nResult = 33  -- Cta Destino cancelada y/o anulada
																	END
																	ELSE	
																	BEGIN												
																		-- VERIFICAR TIPO DE CUENTAS (ORIGEN Y DESTINO)
																		IF (SUBSTRING(@cCtaCodOrigen,6,3) NOT IN('232','237') or @lnDepositoJuvenil = 1)
																		BEGIN
																			SET @nResult = 34 -- Cta. Cargo con tipo incorrecto
																		END
																		ELSE
																		BEGIN
																			IF @lnPagoLote = 0 
																			BEGIN	
																				IF (SUBSTRING(@cCtaCodDestino,6,3) NOT IN('232') OR @lnCuentaRecaudadora = 1 )
																				BEGIN
																					SET @nResult = 34 -- Cta. Abono con tipo incorrecto
																				END
																				ELSE
																				BEGIN												
																					 --VERIFICAR QUE LA MONENDA SEA LA CORRECTA
																					IF SUBSTRING(@cCtaCodOrigen,9,1) <> @lnMoneda
																					begin
																						SET @nResult = 81 -- Moneda de Transaccion Incorrecta
																					end
																					IF @nMonto <= 0
																					begin
																						SET @nResult = 70 --monto de transferencia inválido	
																					end
																					ELSE
																					BEGIN
																						IF @cCtaCodDestino = @cCtaCodOrigen
																						BEGIN
																							SET @nResult = 72 --Cuentas iguales
																						END
																						else	
																						begin
																							---VERIFICAR QUE ESTE DENTRO DEL LIMITE OPERATIVO
																							--Se valida Limites Operativos y Horarios de pago
																							EXEC dbo.spu_App_LimitesOperativos @cCtaCodOrigen,'TxC',@nTipoIDOrigen,@cNroIDOrigen,@nMoneda,@nMonto,@nResulLimite OUTPUT, @cMensaje output
																				
																							IF @nResulLimite <> 0
																							BEGIN 
																								If @nResulLimite = 1
																									SET @nResult = 85
																								If @nResulLimite = 2
																									SET @nResult = 82
																								If @nResulLimite = 3
																									SET @nResult = 83
																								If @nResulLimite = 4
																									SET @nResult = 84
																							END	
																							ELSE
																							BEGIN
																								-- PMRS YYYY/MM/DD Quitar validacion de horario
																								IF @dhoraOperacion <= @dHorarioInicio OR @dhoraOperacion > @dHorarioFin
																								BEGIN
																									SET @nResult = 39 --Operación no válida para el horario
																								END
																							END																	
																						end																				
																					END																			
																				END
																			END
																			ELSE -- ES UN PAGO EN LOTE
																			BEGIN
																				IF SUBSTRING(@cCtaCodDestino,6,3) NOT IN('232','235','236','234','237')												
																				begin
																					SET @nResult = 22 -- Cta. Abono con tipo incorrecto
																				end
																				ELSE
																				BEGIN
																					IF SUBSTRING(@cCtaCodDestino,6,3) = '237'
																					BEGIN
																						IF NOT EXISTS (SELECT 1 FROM DBcmac..CapCtaSueldo WITH(NOLOCK) WHERE cCtaCod = @cCtaCodDestino AND cInstitucion = @lcPerscodOrd) 
																						begin
																							SET @nResult = 34 -- Cta. Abono no pertenece a persona
																						end
																					END
																					IF SUBSTRING(@cCtaCodDestino,6,3) = '234'
																					BEGIN
																						IF NOT EXISTS (SELECT 1 FROM DBcmac..CaptacCTS WITH(NOLOCK) WHERE cCtaCod = @cCtaCodDestino AND cCodInst = @lcPerscodOrd) 
																						begin
																							SET @nResult = 38 -- Cta. Abono no pertenece a persona
																						end
																					END												
																															
																					--VERIFICAR QUE LA MONEDA SEA LA CORRECTA
																					IF SUBSTRING(@cCtaCodOrigen,9,1) <> @lnMoneda 
																					begin
																						SET @nResult = 81 -- Moneda de Transaccion Incorrecta
																					end
																		
																					IF @nMonto <= 0
																					begin
																						SET @nResult = 70 --monto de transferencia inválido	
																					end
																					else
																					begin
																						IF @cCtaCodDestino = @cCtaCodDestino
																						BEGIN
																							SET @nResult = 72 --Cuentas iguales
																						END
																						ELSE	
																						BEGIN
																							---VERIFICAR QUE ESTE DENTRO DEL LIMITE OPERATIVO
																							EXEC dbo.spu_App_LimitesOperativos @cCtaCodOrigen,'T',@nTipoIDOrigen,@cNroIDOrigen,@nMoneda,@nMonto,@nResulLimite OUTPUT, @cMensaje output
																				
																							IF @nResulLimite <> 0
																							BEGIN 
																								If @nResulLimite = 1
																									SET @nResult = 85
																								If @nResulLimite = 2
																									SET @nResult = 82
																								If @nResulLimite = 3
																									SET @nResult = 83
																								If @nResulLimite = 4
																									SET @nResult = 84
																							END
																							--Se valida Horarios de pago	
																							ELSE
																							BEGIN
																								-- PMRS YYYY/MM/DD Quitar validación de horario
																								IF @dhoraOperacion <= @dHorarioInicio OR @dhoraOperacion > @dHorarioFin
																								BEGIN
																									SET @nResult = 39 --Operación no válida para el horario
																								END
																							END		
																							--Se valida Horarios de pago															
																						END
																					end
																				END														
																			END
																		END
																	END
																END
															END
														END
													END
												END
											END
										END
									END
								END
							END
						END
					END--Misma Moneda
				END--Misma persona
				
					if @nResult = -1 and @lnTipoCambioUnica = 0
					begin
						SET @nResult = 89 -- Moneda de Transaccion Incorrecta
						--Corrección de ortografía en mensajes de error.
						--SET @cMensaje = 'No se encontro tipo de cambio'
						SET @cMensaje = 'No se encontró tipo de cambio.'
						--SELECT RIGHT('0' + CAST(@nResult AS VARCHAR(2)),2) cRespuesta, @cMensaje cMensaje, @IDAutoriza nIdAutoriza--01/08/2023 DHFI Se comenta
						SELECT RIGHT('0' + CAST(@nResult AS VARCHAR(2)),2) cRespuesta, @cMensaje cMensaje, @IDAutoriza nIdAutoriza,@cNomEntidad cNomEntidad, '' cNombreAp, @cCtaCodOrigen cCtaCodOrigen----01/08/2023 DHFI Se agrega entidad y nombre
						--commit tran TR_Transferencia
					end	
					-- ============FIN VALIDACIONES PREVIAS ===============
				
						IF @nResult = -1		
						BEGIN

							IF @nCierreDiario = 0			
							BEGIN -- PMRS YYYY/MM/DD Inicio lógica actual
								BEGIN TRY 
									BEGIN TRAN TR_Transferencia				
										-- ============== DETERMINAR SI LA OPERACION ES EN LA MISMA MONEDA ES INTERMONEDA ==============
										SET @cMensaje = 'CORRECTO'
										-- Obtener tipo cambio		
										set @lnTipoCambio = 0
											
										Select	  @nTipoCambioVenta=nValVent
												, @nTipoCambioCompra=nValComp				
										from DBCMAC..TipoCambio with(nolock)
										Where dFecCamb >=@ldFechaSistema and dFecCamb < @ldFechaSistema + 1
									
										set @lnMonedaCargo = SUBSTRING(@cCtaCodOrigen,9,1)
										set @lnMonedaAbono = SUBSTRING(@cCtaCodDestino,9,1)

										if (@lnMonedaCargo<>@lnMonedaAbono)
										begin
											if @lnMonedaAbono = 1
												set @lnTipoCambio = @nTipoCambioCompra
											else 
												set @lnTipoCambio = @nTipoCambioVenta
										end
										-- END Obtener tipo cambio	
										IF @lnMonedaCargo = @lnMonedaAbono		-- tranferencia misma moneda
										BEGIN
											--print 'Entra a operacion normal'
											SET @lnMontoAbono = @nMonto
											SET @lnMontoRetiro = @nMonto
											IF SUBSTRING(@cCtaCodOrigen,6,3) = '234'
												SET @lcOpeCodCargo = '208252'
											ELSE
												SET @lcOpeCodCargo = '208264'--'208251'--Se cambia para TxC CMAC Cargo
										END
										ELSE	-- tranferencia intermoneda
										BEGIN		
											
											SET @lnMontoRetiro = @nMonto
											IF @lnMoneda = 1		-- de soles a dolares
												SET @lnMontoAbono = round(@nMonto/@lnTipoCambio, 2)	  -- CAMBIO DE SOLES A DOLARES
											ELSE					-- de dolares a soles
												SET @lnMontoAbono = round(@nMonto*@lnTipoCambio, 2)   -- CAMBIO DE DOLARES A SOLES
										
											IF SUBSTRING(@cCtaCodOrigen,6,3) = '234'
												SET @lcOpeCodCargo = '208255'
											ELSE
												SET @lcOpeCodCargo = '208254' 
										EXEC dbo.spu_App_Cap_RegistroOperacionIntermoneda @ldFechaSistema, @cCtaCodOrigen, @lnMonedaAbono, @nMonto, @lnMontoAbono, '701308', @cUser, @lnTipoCambio, @lnMovNroAsiento OUTPUT, @lnResultAsiento OUTPUT --08/02/2023 DHFI Se agrega cod operacion intermoneda
											
											IF @lnResultAsiento <> 0
											BEGIN
												SET @nResult = @lnResultAsiento  -- 1 ERROR EN REGISTRO DE OPERACION INTERMONEDA
												SELECT 0/0 -- FORZAR ERROR
											END
										END
									
										SET @lnMontoRetiro = CAST(@lnMontoRetiro AS NUMERIC(15,2))
										SET @lnMontoAbono = CAST(@lnMontoAbono AS NUMERIC(15,2))
										SELECT @lcOpeCodAbono = CASE WHEN SUBSTRING(@cCtaCodDestino,6,3)='234' THEN '208183'
																	WHEN SUBSTRING(@cCtaCodDestino,6,3)='233' THEN '208250'-- codigo de dep plazo fijo flexible
																	ELSE '208265'--'208253'--Se cambia para TxC CMAC Abono
																END

										SELECT @lnITF = ISNULL(CONVERT(DECIMAL(18,5), nConsSisvalor),0) FROM DBCmac..ConstSistema with(nolock) WHERE nConsSiscod = 156

										--CALCULAR ITF
										EXEC dbo.spu_HB_VerficaMismoTitularDeCuentasTransferencia @cCtaCodOrigen, @cCtaCodDestino, @lnResultITF OUTPUT

										--se valida intermoneda de propias para no exonerar ITF
										IF @lnMonedaCargo <> @lnMonedaAbono AND @lnResultITF = 0
										BEGIN

											SET @lnResultITF = 1
										END
										--Se agrega validacion ITF para cuenta destino infantil, juvenil, mancomuncada,indistinta
										IF (@lnResultITF = 0 and (@nInfantil=1 or @nJuvenil=1 or @nIndistinta=1 or @nMancomunada=1))
										BEGIN
											SET @lnResultITF = 1
										END
										--Se agrega validacion ITF para cuenta destino infantil, juvenil, mancomuncada,indistinta

										IF @lnResultITF =0
										BEGIN
											SET @lnMontoITFRetiro = 0
											SET @lnMontoITFAbono = 0
										END
										ELSE
										BEGIN
											EXEC dbo.[ATM_RecuperaCtaExoITF] @cCtaCodOrigen, @lnResultExoneraITF OUTPUT
											IF @lnResultExoneraITF= 1 OR SUBSTRING(@cCtaCodOrigen,6,3) IN('237','234')
												SET @lnMontoITFRetiro = 0
											ELSE
											BEGIN
												SET @lnMontoITFRetiro = round(@lnMontoRetiro * @lnITF, 2, 1)
												SELECT @lnMontoITFRetiro = dbo.fn_BM_RedondeaITFAMultiplo05HaciaAbajo(@lnMontoITFRetiro)
											END

											SET @lnResultExoneraITF = 0
											EXEC dbo.[ATM_RecuperaCtaExoITF] @cCtaCodDestino, @lnResultExoneraITF OUTPUT
											IF @lnResultExoneraITF= 1 OR SUBSTRING(@cCtaCodDestino,6,3) IN('237','234')  					
												SET @lnMontoITFAbono = 0
											ELSE					
											BEGIN		
												SET @lnMontoITFAbono = ROUND(@lnMontoAbono * @lnITF, 2, 1)
												SELECT @lnMontoITFAbono = dbo.fn_BM_RedondeaITFAMultiplo05HaciaAbajo(@lnMontoITFAbono)
											END
										END
									
										--****************** CALCULAR COMISION INTER PLAZA **********************								
										SET @lnMontoComisionOtraPlaza = 0		--no se cobra comision otra plaza				

									
										-- ****************** ACTUALIZAR CON cOpeCods de APP MOVIL ***********************								
										EXEC dbo.spu_App_CargoCuenta @cCtaCodOrigen, @lnMontoRetiro, @lnMontoITFRetiro, @lnMontoComisionOtraPlaza, 0, @ldFechaSistema, @lcOpeCodCargo, '990336', @cUser, @lnResultRetiro OUTPUT, @lnMovNroRet OUTPUT 	

										IF @lnResultRetiro <> 0
										BEGIN					
											SELECT @nResult = CASE @lnResultRetiro WHEN 3 THEN 20   -- Estado de cuenta invalido
																					WHEN 4 THEN 18   -- Sin saldo 
																					WHEN 20 THEN 87  -- Error en Cargo desconocido		
																					WHEN 21 THEN 96 --Se muestra mensaje en caso de trasnferencia duplicada		 										    
																					ELSE 87        -- Error en cargo conocido
															END
										END
										ELSE
										BEGIN								
											-- ===== REGISTRAR LAVADO DE ACTIVOS RETIRO APP MOVIL ======
									
											IF @lnMonedaCargo = 2
											BEGIN
												IF @lnMontoRetiro >= @lnUmbralLavadoActivos
												BEGIN
													INSERT INTO MovLavDineroApp (nMovNro, cCtaCod, cPersCod, cPersCodBen, cPersCodTra, nTipoOpe)
													VALUES(@lnMovNroRet, @cCtaCodOrigen, @lcPerscodOrd, @lcPerscodBen, @lcPerscodOrd, 1)
												END
											END
											ELSE 
											BEGIN
												IF (@lnMontoRetiro/@lnTipoCambioUnica) >= @lnUmbralLavadoActivos
												BEGIN
													INSERT INTO MovLavDineroApp (nMovNro, cCtaCod, cPersCod, cPersCodBen, cPersCodTra, nTipoOpe)
													VALUES(@lnMovNroRet, @cCtaCodOrigen, @lcPerscodOrd, @lcPerscodBen, @lcPerscodOrd, 1)
												END

											END
											--Se obtiene cod operacion dep ITF
											Declare @cCodOpeITF Varchar(6)
											Select @cCodOpeITF = '990336'--CASE WHEN SUBSTRING(@cCtaCodDestino,6,3)='233' THEN '990334' ELSE '990331' END
											--Se obtiene cod operacion ITF
											-- ****************** ACTUALIZAR CON cOpeCods de APP MOVIL ***********************					
											EXEC dbo.spu_App_AbonoCuenta @cCtaCodDestino, @lnMontoAbono, @lnMontoITFAbono, 0, 0, @ldFechaSistema, @lcOpeCodAbono, @cCodOpeITF, @cUser, 0, @lnResultAbono OUTPUT, @lnMovNroDep OUTPUT --08/02/2023 DHFI Se cambia cod operacion ITF
											IF @lnResultAbono <> 0
											BEGIN
												SELECT @nResult = CASE @lnResultAbono WHEN 1 THEN 20   -- Estado de Cuenta Invalido
																					WHEN 2 THEN 71   -- Saldo Insuficiente														   
																					WHEN 5 THEN 87   -- Error de Transaccion Conocido
																					ELSE 87		   -- Error de Transaccion Desconocido
																END
											END	
											ELSE
											BEGIN
									
												IF SUBSTRING(@cCtaCodDestino,9,1)= '2'
												BEGIN
													IF @lnMontoAbono >= @lnUmbralLavadoActivos
													BEGIN
														INSERT INTO MovLavDineroApp (nMovNro, cCtaCod, cPersCod, cPersCodBen, cPersCodTra, nTipoOpe)
														VALUES(@lnMovNroDep, @cCtaCodDestino, @lcPerscodOrd, @lcPerscodBen, @lcPerscodOrd, 2)
													END
												END
												ELSE 
												BEGIN
													IF (@lnMontoAbono / @lnTipoCambioUnica ) >= @lnUmbralLavadoActivos
													BEGIN
														INSERT INTO MovLavDineroApp (nMovNro, cCtaCod, cPersCod, cPersCodBen, cPersCodTra, nTipoOpe)
														VALUES(@lnMovNroDep, @cCtaCodDestino, @lcPerscodOrd, @lcPerscodBen, @lcPerscodOrd, 2)
													END
										
												END
									
											
												--Registrar Operacion en AppMov
												INSERT INTO AppMov(IDPagoLote, IDPago, IdOperacion, nMovNro1, nMovNro2, nMovnro3, dFechaReal, dFechaSist, cCodOperacion, nMoneda, cCtaCodOrigen, cCtaCodDestino, nMonto, nTipoCambio, nMovFlag, cNumTarjeta) 
												VALUES(NULL, NULL, NULL, @lnMovNroRet, @lnMovNroDep, @lnMovNroAsiento, GETDATE(), @ldFechaSistema, @cAppTipoTransferencia, @lnMoneda, @cCtaCodOrigen, @cCtaCodDestino, @nMonto, @lnTipoCambio, 0, @cNumTarjeta) --02/12/2019 LVCH Se agrega #tarjeta
									
												IF @@ERROR <>0 OR @@ROWCOUNT < 1
												SET @nResult = 91

												SET @IDAutoriza = @@IDENTITY
									
												IF @nResult = -1
													SET @nResult=0
												--Se Registra operacion Correcta en tabla de TxC
												DECLARE @cNombreClienteOrigen varchar(140)		--Nombre del Cliente Originante.
												DECLARE @cNombreClienteDestino varchar(140)		--Nombre del Cliente Destino.
												--Nombre Origen
												Declare  @cNombreO varchar(100)
												DEclare  @cApellidoO varchar(100)
												SELECT @cNombreO = CASE WHEN ISNULL(PATINDEX('%,%', P.cPersNombre),0) = 0 THEN '' ELSE LEFT(UPPER(SUBSTRING(P.cPersNombre, PATINDEX('%,%', P.cPersNombre) + 1, LEN(P.cPersNombre))),100) END,
													@cApellidoO = LEFT(UPPER(SUBSTRING(REPLACE(P.cPersNombre, '/', '\'), 1, CASE WHEN CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) <1 THEN len(P.cPersNombre) ELSE CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) END - 1)),50)
													+' ' + LEFT(UPPER(CASE WHEN LEN(LTRIM(RTRIM(SUBSTRING(REPLACE(P.cPersNombre, '/', '\'), CASE WHEN CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) <1 THEN 0 ELSE CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) END + 1, 
													CASE WHEN CHARINDEX(',', P.cPersNombre, 1) - (CASE WHEN CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) <1 THEN 1 ELSE CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) END -1)<0 THEN 0
													ELSE CHARINDEX(',', P.cPersNombre, 1) - (CASE WHEN CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) <1 THEN 1 ELSE CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) END -1) END)))) < 2 THEN ''         
													ELSE SUBSTRING(REPLACE(P.cPersNombre, '/', '\'), 
													CASE WHEN CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) <1 THEN 0 ELSE CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) END
													+ 1, CHARINDEX(',', P.cPersNombre, 1) - 
													CASE WHEN CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) <1 THEN 1 ELSE CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) END
													--- 1) END),50)     from DBCMAC..productopersona pp with (NOLOCK) INNER JOIN DBCMAC..persona p with (NOLOCK) ON pp.cPersCod=p.cPersCod where cCtaCod = @cCtaCodOrigen
													- 1) END),50)
													from DBCMAC..productopersona pp with (NOLOCK) INNER JOIN DBCMAC..persona p with (NOLOCK) ON pp.cPersCod=p.cPersCod where p.cperscod=@lcPerscodOrd--10/06/2022 DHFI Se recupera el cperscod para definir nombre de cliente
								
												Select @cNombreClienteOrigen = @cNombreO +' '+ @cApellidoO
												--Nombre Destino
												Declare  @cNombreD varchar(100)
												DEclare  @cApellidoD varchar(100)
												SELECT @cNombreD = CASE WHEN ISNULL(PATINDEX('%,%', P.cPersNombre),0) = 0 THEN '' ELSE LEFT(UPPER(SUBSTRING(P.cPersNombre, PATINDEX('%,%', P.cPersNombre) + 1, LEN(P.cPersNombre))),100) END,
													@cApellidoD = LEFT(UPPER(SUBSTRING(REPLACE(P.cPersNombre, '/', '\'), 1, CASE WHEN CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) <1 THEN len(P.cPersNombre) ELSE CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) END - 1)),50)
													+' ' + LEFT(UPPER(CASE WHEN LEN(LTRIM(RTRIM(SUBSTRING(REPLACE(P.cPersNombre, '/', '\'), CASE WHEN CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) <1 THEN 0 ELSE CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) END + 1, 
													CASE WHEN CHARINDEX(',', P.cPersNombre, 1) - (CASE WHEN CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) <1 THEN 1 ELSE CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) END -1)<0 THEN 0
													ELSE CHARINDEX(',', P.cPersNombre, 1) - (CASE WHEN CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) <1 THEN 1 ELSE CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) END -1) END)))) < 2 THEN ''         
													ELSE SUBSTRING(REPLACE(P.cPersNombre, '/', '\'), 
													CASE WHEN CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) <1 THEN 0 ELSE CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) END
													+ 1, CHARINDEX(',', P.cPersNombre, 1) - 
													CASE WHEN CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) <1 THEN 1 ELSE CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) END
													--- 1) END),50)     from DBCMAC..productopersona pp with (NOLOCK) INNER JOIN DBCMAC..persona p with (NOLOCK) ON pp.cPersCod=p.cPersCod where cCtaCod = @cCtaCodOrigen
													- 1) END),50)
													from DBCMAC..productopersona pp with (NOLOCK) INNER JOIN DBCMAC..persona p with (NOLOCK) ON pp.cPersCod=p.cPersCod where p.cperscod=@lcPerscodBen--10/06/2022 DHFI Se recupera el cperscod para definir nombre de cliente
								
												Select @cNombreClienteDestino = @cNombreD +' '+ @cApellidoD

												INSERT INTO App_TransferenciaContacto (nMovNro,cCanal,nMonto,nMoneda,cNroDocOrig,cNroDocDesti,cCtaOrigen
																,cCtaDestino,cNroCelDestino,nComision,nITF,cNombreOrigen,cNombreDestino,dFechaReal)
															VALUES(@lnMovNroRet,@cCanal,@nMonto,1,@cNroIDOrigen,@cNroIDDestino,@cCtaCodOrigen
																,@cCtaCodDestino,@cCelularClienteReceptor,0,@lnMontoITFRetiro,@cNombreClienteOrigen,@cNombreClienteDestino,GETDATE())
												--Se Registra operacion Correcta en tabla de TxC
											END
										END
								
									IF @nResult > 0
										SELECT @cMensaje = cDescError FROM CodigosError WITH(NOLOCK) WHERE cCodError = @nResult

									IF @nResult = 0
									BEGIN
										UPDATE appeventos SET nIdTransaccionApp = @IDAutoriza, dFechaSist = @ldFechaSistema Where IdOperacion = @nIdEvento
										--SELECT RIGHT('0' + CAST(@nResult AS VARCHAR(2)),2) cRespuesta, @cMensaje cMensaje, @IDAutoriza nIdAutoriza--01/08/2023 DHFI Se comenta
										SELECT RIGHT('0' + CAST(@nResult AS VARCHAR(2)),2) cRespuesta, @cMensaje cMensaje, @IDAutoriza nIdAutoriza,@cNomEntidad cNomEntidad, @cNombreClienteDestino cNombreAp, @cCtaCodOrigen cCtaCodOrigen----01/08/2023 DHFI Se agrega entidad y nombre 
										COMMIT TRAN TR_Transferencia								
									END
									ELSE
									BEGIN
										--SELECT RIGHT('0' + CAST(@nResult AS VARCHAR(2)),2) cRespuesta, @cMensaje cMensaje, @IDAutoriza nIdAutoriza--01/08/2023 DHFI Se comenta
										SELECT RIGHT('0' + CAST(@nResult AS VARCHAR(2)),2) cRespuesta, @cMensaje cMensaje, @IDAutoriza nIdAutoriza,@cNomEntidad cNomEntidad, @cNombreClienteDestino cNombreAp, @cCtaCodOrigen cCtaCodOrigen----01/08/2023 DHFI Se agrega entidad y nombre
										ROLLBACK TRAN TR_Transferencia
									END	

									--EVENTOS
									INSERT INTO AppEventos VALUES (@IDAutoriza,@cAppTipoTransferencia,'Transferencia', GETDATE(),@ldFechaSistema,@cCtaCodOrigen,@cCtaCodDestino,@nResult,@cMensaje)
									--EVENTOS	

								END TRY
								BEGIN CATCH						
									IF @nResult = -1
										SET @nResult = 12
									SET @IDAutoriza = 0
									SET @cMensaje = ERROR_MESSAGE()	 				
									
									--SELECT RIGHT('0' + CAST(@nResult AS VARCHAR(2)),2) cRespuesta, @cMensaje cMensaje, @IDAutoriza nIdAutoriza--01/08/2023 DHFI Se comenta
									SELECT RIGHT('0' + CAST(@nResult AS VARCHAR(2)),2) cRespuesta, @cMensaje cMensaje, @IDAutoriza nIdAutoriza,@cNomEntidad cNomEntidad, @cNombreClienteDestino cNombreAp, @cCtaCodOrigen cCtaCodOrigen----01/08/2023 DHFI Se agrega entidad y nombre
									ROLLBACK TRAN TR_Transferencia
									--EVENTOS
									INSERT INTO AppEventos VALUES (0,@cAppTipoTransferencia,'Transferencia', GETDATE(),@ldFechaSistema,@cCtaCodOrigen,@cCtaCodDestino,@nResult,@cMensaje)
									SET @cMensaje = 'Ocurrió un error durante la transacción.' --24/12/2019 LVCH --se optimia mensaje
									--EVENTOS
								END	CATCH
							END -- PMRS YYYY/MM/DD Fin lógica actual
							ELSE
							BEGIN -- PMRS YYYY/MM/DD Inicio lógica offhost
								BEGIN TRY 
									BEGIN TRAN TR_Transferencia_OffHost				
										-- ============== DETERMINAR SI LA OPERACION ES EN LA MISMA MONEDA ES INTERMONEDA ==============
										SET @cMensaje = 'CORRECTO'
										-- Obtener tipo cambio		
										set @lnTipoCambio = 0
											
										Select	  @nTipoCambioVenta=nValVent
												, @nTipoCambioCompra=nValComp				
										from DBCMAC..TipoCambio with(nolock)
										Where dFecCamb >=@ldFechaSistema and dFecCamb < @ldFechaSistema + 1
									
										set @lnMonedaCargo = SUBSTRING(@cCtaCodOrigen,9,1)
										set @lnMonedaAbono = SUBSTRING(@cCtaCodDestino,9,1)

										if (@lnMonedaCargo<>@lnMonedaAbono)
										begin
											if @lnMonedaAbono = 1
												set @lnTipoCambio = @nTipoCambioCompra
											else 
												set @lnTipoCambio = @nTipoCambioVenta
										end
										-- END Obtener tipo cambio	
										IF @lnMonedaCargo = @lnMonedaAbono		-- tranferencia misma moneda
										BEGIN
											--print 'Entra a operacion normal'
											SET @lnMontoAbono = @nMonto
											SET @lnMontoRetiro = @nMonto
											IF SUBSTRING(@cCtaCodOrigen,6,3) = '234'
												SET @lcOpeCodCargo = '208252'
											ELSE
												SET @lcOpeCodCargo = '208264'--'208251'--Se cambia para TxC CMAC Cargo
										END
										ELSE	-- tranferencia intermoneda
										BEGIN		
											
											SET @lnMontoRetiro = @nMonto
											IF @lnMoneda = 1		-- de soles a dolares
												SET @lnMontoAbono = round(@nMonto/@lnTipoCambio, 2)	  -- CAMBIO DE SOLES A DOLARES
											ELSE					-- de dolares a soles
												SET @lnMontoAbono = round(@nMonto*@lnTipoCambio, 2)   -- CAMBIO DE DOLARES A SOLES
										
											IF SUBSTRING(@cCtaCodOrigen,6,3) = '234'
												SET @lcOpeCodCargo = '208255'
											ELSE
												SET @lcOpeCodCargo = '208254' 
										EXEC dbo.spu_App_Cap_RegistroOperacionIntermoneda @ldFechaSistema, @cCtaCodOrigen, @lnMonedaAbono, @nMonto, @lnMontoAbono, '701308', @cUser, @lnTipoCambio, @lnMovNroAsiento OUTPUT, @lnResultAsiento OUTPUT --08/02/2023 DHFI Se agrega cod operacion intermoneda
											
											IF @lnResultAsiento <> 0
											BEGIN
												SET @nResult = @lnResultAsiento  -- 1 ERROR EN REGISTRO DE OPERACION INTERMONEDA
												SELECT 0/0 -- FORZAR ERROR
											END
										END
									
										SET @lnMontoRetiro = CAST(@lnMontoRetiro AS NUMERIC(15,2))
										SET @lnMontoAbono = CAST(@lnMontoAbono AS NUMERIC(15,2))
										SELECT @lcOpeCodAbono = CASE WHEN SUBSTRING(@cCtaCodDestino,6,3)='234' THEN '208183'
																	WHEN SUBSTRING(@cCtaCodDestino,6,3)='233' THEN '208250'-- codigo de dep plazo fijo flexible
																	ELSE '208265'--'208253'--Se cambia para TxC CMAC Abono
																END

										SELECT @lnITF = ISNULL(CONVERT(DECIMAL(18,5), nConsSisvalor),0) FROM DBCmac..ConstSistema with(nolock) WHERE nConsSiscod = 156

										--CALCULAR ITF
										EXEC dbo.spu_HB_VerficaMismoTitularDeCuentasTransferencia @cCtaCodOrigen, @cCtaCodDestino, @lnResultITF OUTPUT

										--se valida intermoneda de propias para no exonerar ITF
										IF @lnMonedaCargo <> @lnMonedaAbono AND @lnResultITF = 0
										BEGIN

											SET @lnResultITF = 1
										END
										--Se agrega validacion ITF para cuenta destino infantil, juvenil, mancomuncada,indistinta
										IF (@lnResultITF = 0 and (@nInfantil=1 or @nJuvenil=1 or @nIndistinta=1 or @nMancomunada=1))
										BEGIN
											SET @lnResultITF = 1
										END
										--Se agrega validacion ITF para cuenta destino infantil, juvenil, mancomuncada,indistinta

										IF @lnResultITF =0
										BEGIN
											SET @lnMontoITFRetiro = 0
											SET @lnMontoITFAbono = 0
										END
										ELSE
										BEGIN
											EXEC dbo.[ATM_RecuperaCtaExoITF] @cCtaCodOrigen, @lnResultExoneraITF OUTPUT
											IF @lnResultExoneraITF= 1 OR SUBSTRING(@cCtaCodOrigen,6,3) IN('237','234')
												SET @lnMontoITFRetiro = 0
											ELSE
											BEGIN
												SET @lnMontoITFRetiro = round(@lnMontoRetiro * @lnITF, 2, 1)
												SELECT @lnMontoITFRetiro = dbo.fn_BM_RedondeaITFAMultiplo05HaciaAbajo(@lnMontoITFRetiro)
											END

											SET @lnResultExoneraITF = 0
											EXEC dbo.[ATM_RecuperaCtaExoITF] @cCtaCodDestino, @lnResultExoneraITF OUTPUT
											IF @lnResultExoneraITF= 1 OR SUBSTRING(@cCtaCodDestino,6,3) IN('237','234')  					
												SET @lnMontoITFAbono = 0
											ELSE					
											BEGIN		
												SET @lnMontoITFAbono = ROUND(@lnMontoAbono * @lnITF, 2, 1)
												SELECT @lnMontoITFAbono = dbo.fn_BM_RedondeaITFAMultiplo05HaciaAbajo(@lnMontoITFAbono)
											END
										END
									
										--****************** CALCULAR COMISION INTER PLAZA **********************								
										SET @lnMontoComisionOtraPlaza = 0		--no se cobra comision otra plaza				

									
										-- ****************** ACTUALIZAR CON cOpeCods de APP MOVIL ***********************								
										EXEC dbo.spu_App_CargoCuenta_OffHost @cCtaCodOrigen, @lnMontoRetiro, @lnMontoITFRetiro, @lnMontoComisionOtraPlaza, 0, @ldFechaSistema, @lcOpeCodCargo, '990336', @cUser, @lnResultRetiro OUTPUT, @lnMovNroRet OUTPUT 	

										IF @lnResultRetiro <> 0
										BEGIN					
											SELECT @nResult = CASE @lnResultRetiro WHEN 3 THEN 20   -- Estado de cuenta invalido
																					WHEN 4 THEN 18   -- Sin saldo 
																					WHEN 20 THEN 87  -- Error en Cargo desconocido		
																					WHEN 21 THEN 96 --Se muestra mensaje en caso de trasnferencia duplicada		 										    
																					ELSE 87        -- Error en cargo conocido
															END
										END
										ELSE
										BEGIN								
											-- ===== REGISTRAR LAVADO DE ACTIVOS RETIRO APP MOVIL ======
									
											IF @lnMonedaCargo = 2
											BEGIN
												IF @lnMontoRetiro >= @lnUmbralLavadoActivos
												BEGIN
													INSERT INTO MovLavDineroApp (nMovNro, cCtaCod, cPersCod, cPersCodBen, cPersCodTra, nTipoOpe)
													VALUES(@lnMovNroRet, @cCtaCodOrigen, @lcPerscodOrd, @lcPerscodBen, @lcPerscodOrd, 1)
												END
											END
											ELSE 
											BEGIN
												IF (@lnMontoRetiro/@lnTipoCambioUnica) >= @lnUmbralLavadoActivos
												BEGIN
													INSERT INTO MovLavDineroApp (nMovNro, cCtaCod, cPersCod, cPersCodBen, cPersCodTra, nTipoOpe)
													VALUES(@lnMovNroRet, @cCtaCodOrigen, @lcPerscodOrd, @lcPerscodBen, @lcPerscodOrd, 1)
												END

											END
											--Se obtiene cod operacion dep ITF
											-- PMRS YYYY/MM/DD Variable ya fue definida
											-- Declare @cCodOpeITF Varchar(6)
											Select @cCodOpeITF = '990336'--CASE WHEN SUBSTRING(@cCtaCodDestino,6,3)='233' THEN '990334' ELSE '990331' END
											--Se obtiene cod operacion ITF
											-- ****************** ACTUALIZAR CON cOpeCods de APP MOVIL ***********************					
											EXEC dbo.spu_App_AbonoCuenta_OffHost @cCtaCodDestino, @lnMontoAbono, @lnMontoITFAbono, 0, 0, @ldFechaSistema, @lcOpeCodAbono, @cCodOpeITF, @cUser, 0, @lnResultAbono OUTPUT, @lnMovNroDep OUTPUT --08/02/2023 DHFI Se cambia cod operacion ITF
											IF @lnResultAbono <> 0
											BEGIN
												SELECT @nResult = CASE @lnResultAbono WHEN 1 THEN 20   -- Estado de Cuenta Invalido
																					WHEN 2 THEN 71   -- Saldo Insuficiente														   
																					WHEN 5 THEN 87   -- Error de Transaccion Conocido
																					ELSE 87		   -- Error de Transaccion Desconocido
																END
											END	
											ELSE
											BEGIN
									
												IF SUBSTRING(@cCtaCodDestino,9,1)= '2'
												BEGIN
													IF @lnMontoAbono >= @lnUmbralLavadoActivos
													BEGIN
														INSERT INTO MovLavDineroApp (nMovNro, cCtaCod, cPersCod, cPersCodBen, cPersCodTra, nTipoOpe)
														VALUES(@lnMovNroDep, @cCtaCodDestino, @lcPerscodOrd, @lcPerscodBen, @lcPerscodOrd, 2)
													END
												END
												ELSE 
												BEGIN
													IF (@lnMontoAbono / @lnTipoCambioUnica ) >= @lnUmbralLavadoActivos
													BEGIN
														INSERT INTO MovLavDineroApp (nMovNro, cCtaCod, cPersCod, cPersCodBen, cPersCodTra, nTipoOpe)
														VALUES(@lnMovNroDep, @cCtaCodDestino, @lcPerscodOrd, @lcPerscodBen, @lcPerscodOrd, 2)
													END
										
												END
									
											
												--Registrar Operacion en AppMov
												INSERT INTO AppMov(IDPagoLote, IDPago, IdOperacion, nMovNro1, nMovNro2, nMovnro3, dFechaReal, dFechaSist, cCodOperacion, nMoneda, cCtaCodOrigen, cCtaCodDestino, nMonto, nTipoCambio, nMovFlag, cNumTarjeta) 
												-- PMRS YYYY/MM/DD Se inserta con flag 1 para saber que es en offhost
												VALUES(NULL, NULL, NULL, @lnMovNroRet, @lnMovNroDep, @lnMovNroAsiento, GETDATE(), @ldFechaSistema, @cAppTipoTransferencia, @lnMoneda, @cCtaCodOrigen, @cCtaCodDestino, @nMonto, @lnTipoCambio, 1, @cNumTarjeta) --02/12/2019 LVCH Se agrega #tarjeta

												DECLARE @nIDAppMov INT = SCOPE_IDENTITY()

												-- PMRS YYYY/MM/DD Se guarda registro de movimientos offhost
												INSERT DBTarjeta..MovRefOffHostApp
													(
														nIDTransaccionAPP, nMoneda, nMonto, cUser, dFechaReal,
														nOffHostMovNroAbono, cCtaCodAbono, cOpeCodAbono, nMontoITFAbono, nMontoComisionAbono, cOpeCodITFAbono,
														nOffHostMovNroCargo, cCtaCodCargo, cOpeCodCargo, nMontoITFCargo, nMontoComisionCargo, cOpeCodITFCargo
													)
												VALUES
													(
														@nIDAppMov, @nMoneda, @nMonto, @cUser, GETDATE(),
														@lnMovNroDep, @cCtaCodDestino, @lcOpeCodAbono, @lnMontoITFAbono, 0, @cCodOpeITF,
														@lnMovNroRet, @cCtaCodOrigen, @lcOpeCodCargo, @lnMontoITFRetiro, @lnMontoComisionOtraPlaza, '990336'
													)
									
												IF @@ERROR <>0 OR @@ROWCOUNT < 1
												SET @nResult = 91

												SET @IDAutoriza = @@IDENTITY
									
												IF @nResult = -1
													SET @nResult=0
												--Se Registra operacion Correcta en tabla de TxC
												-- PMRS YYYY/MM/DD Variables ya fueron definidas
												-- DECLARE @cNombreClienteOrigen varchar(140)		--Nombre del Cliente Originante.
												-- DECLARE @cNombreClienteDestino varchar(140)		--Nombre del Cliente Destino.
												--Nombre Origen
												-- PMRS YYYY/MM/DD Variables ya fueron definidas
												-- Declare  @cNombreO varchar(100)
												-- DEclare  @cApellidoO varchar(100)
												SELECT @cNombreO = CASE WHEN ISNULL(PATINDEX('%,%', P.cPersNombre),0) = 0 THEN '' ELSE LEFT(UPPER(SUBSTRING(P.cPersNombre, PATINDEX('%,%', P.cPersNombre) + 1, LEN(P.cPersNombre))),100) END,
													@cApellidoO = LEFT(UPPER(SUBSTRING(REPLACE(P.cPersNombre, '/', '\'), 1, CASE WHEN CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) <1 THEN len(P.cPersNombre) ELSE CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) END - 1)),50)
													+' ' + LEFT(UPPER(CASE WHEN LEN(LTRIM(RTRIM(SUBSTRING(REPLACE(P.cPersNombre, '/', '\'), CASE WHEN CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) <1 THEN 0 ELSE CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) END + 1, 
													CASE WHEN CHARINDEX(',', P.cPersNombre, 1) - (CASE WHEN CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) <1 THEN 1 ELSE CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) END -1)<0 THEN 0
													ELSE CHARINDEX(',', P.cPersNombre, 1) - (CASE WHEN CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) <1 THEN 1 ELSE CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) END -1) END)))) < 2 THEN ''         
													ELSE SUBSTRING(REPLACE(P.cPersNombre, '/', '\'), 
													CASE WHEN CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) <1 THEN 0 ELSE CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) END
													+ 1, CHARINDEX(',', P.cPersNombre, 1) - 
													CASE WHEN CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) <1 THEN 1 ELSE CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) END
													--- 1) END),50)     from DBCMAC..productopersona pp with (NOLOCK) INNER JOIN DBCMAC..persona p with (NOLOCK) ON pp.cPersCod=p.cPersCod where cCtaCod = @cCtaCodOrigen
													- 1) END),50)
													from DBCMAC..productopersona pp with (NOLOCK) INNER JOIN DBCMAC..persona p with (NOLOCK) ON pp.cPersCod=p.cPersCod where p.cperscod=@lcPerscodOrd--10/06/2022 DHFI Se recupera el cperscod para definir nombre de cliente
								
												Select @cNombreClienteOrigen = @cNombreO +' '+ @cApellidoO
												--Nombre Destino
												-- PMRS YYYY/MM/DD Variables ya fueron definidas
												-- Declare  @cNombreD varchar(100)
												-- DEclare  @cApellidoD varchar(100)
												SELECT @cNombreD = CASE WHEN ISNULL(PATINDEX('%,%', P.cPersNombre),0) = 0 THEN '' ELSE LEFT(UPPER(SUBSTRING(P.cPersNombre, PATINDEX('%,%', P.cPersNombre) + 1, LEN(P.cPersNombre))),100) END,
													@cApellidoD = LEFT(UPPER(SUBSTRING(REPLACE(P.cPersNombre, '/', '\'), 1, CASE WHEN CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) <1 THEN len(P.cPersNombre) ELSE CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) END - 1)),50)
													+' ' + LEFT(UPPER(CASE WHEN LEN(LTRIM(RTRIM(SUBSTRING(REPLACE(P.cPersNombre, '/', '\'), CASE WHEN CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) <1 THEN 0 ELSE CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) END + 1, 
													CASE WHEN CHARINDEX(',', P.cPersNombre, 1) - (CASE WHEN CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) <1 THEN 1 ELSE CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) END -1)<0 THEN 0
													ELSE CHARINDEX(',', P.cPersNombre, 1) - (CASE WHEN CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) <1 THEN 1 ELSE CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) END -1) END)))) < 2 THEN ''         
													ELSE SUBSTRING(REPLACE(P.cPersNombre, '/', '\'), 
													CASE WHEN CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) <1 THEN 0 ELSE CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) END
													+ 1, CHARINDEX(',', P.cPersNombre, 1) - 
													CASE WHEN CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) <1 THEN 1 ELSE CHARINDEX('\', REPLACE(P.cPersNombre, '/', '\'), 1) END
													--- 1) END),50)     from DBCMAC..productopersona pp with (NOLOCK) INNER JOIN DBCMAC..persona p with (NOLOCK) ON pp.cPersCod=p.cPersCod where cCtaCod = @cCtaCodOrigen
													- 1) END),50)
													from DBCMAC..productopersona pp with (NOLOCK) INNER JOIN DBCMAC..persona p with (NOLOCK) ON pp.cPersCod=p.cPersCod where p.cperscod=@lcPerscodBen--10/06/2022 DHFI Se recupera el cperscod para definir nombre de cliente
								
												Select @cNombreClienteDestino = @cNombreD +' '+ @cApellidoD

												INSERT INTO App_TransferenciaContacto (nMovNro,cCanal,nMonto,nMoneda,cNroDocOrig,cNroDocDesti,cCtaOrigen
																,cCtaDestino,cNroCelDestino,nComision,nITF,cNombreOrigen,cNombreDestino,dFechaReal)
															VALUES(@lnMovNroRet,@cCanal,@nMonto,1,@cNroIDOrigen,@cNroIDDestino,@cCtaCodOrigen
																,@cCtaCodDestino,@cCelularClienteReceptor,0,@lnMontoITFRetiro,@cNombreClienteOrigen,@cNombreClienteDestino,GETDATE())
												--Se Registra operacion Correcta en tabla de TxC
											END
										END
								
									IF @nResult > 0
										SELECT @cMensaje = cDescError FROM CodigosError WITH(NOLOCK) WHERE cCodError = @nResult

									IF @nResult = 0
									BEGIN
										UPDATE appeventos SET nIdTransaccionApp = @IDAutoriza, dFechaSist = @ldFechaSistema Where IdOperacion = @nIdEvento
										--SELECT RIGHT('0' + CAST(@nResult AS VARCHAR(2)),2) cRespuesta, @cMensaje cMensaje, @IDAutoriza nIdAutoriza--01/08/2023 DHFI Se comenta
										SELECT RIGHT('0' + CAST(@nResult AS VARCHAR(2)),2) cRespuesta, @cMensaje cMensaje, @IDAutoriza nIdAutoriza,@cNomEntidad cNomEntidad, @cNombreClienteDestino cNombreAp, @cCtaCodOrigen cCtaCodOrigen----01/08/2023 DHFI Se agrega entidad y nombre 
										COMMIT TRAN TR_Transferencia_OffHost								
									END
									ELSE
									BEGIN
										--SELECT RIGHT('0' + CAST(@nResult AS VARCHAR(2)),2) cRespuesta, @cMensaje cMensaje, @IDAutoriza nIdAutoriza--01/08/2023 DHFI Se comenta
										SELECT RIGHT('0' + CAST(@nResult AS VARCHAR(2)),2) cRespuesta, @cMensaje cMensaje, @IDAutoriza nIdAutoriza,@cNomEntidad cNomEntidad, @cNombreClienteDestino cNombreAp, @cCtaCodOrigen cCtaCodOrigen----01/08/2023 DHFI Se agrega entidad y nombre
										ROLLBACK TRAN TR_Transferencia_OffHost
									END	

									--EVENTOS
									INSERT INTO AppEventos VALUES (@IDAutoriza,@cAppTipoTransferencia,'Transferencia', GETDATE(),@ldFechaSistema,@cCtaCodOrigen,@cCtaCodDestino,@nResult,@cMensaje)
									--EVENTOS	

								END TRY
								BEGIN CATCH						
									IF @nResult = -1
										SET @nResult = 12
									SET @IDAutoriza = 0
									SET @cMensaje = ERROR_MESSAGE()	 				
									
									--SELECT RIGHT('0' + CAST(@nResult AS VARCHAR(2)),2) cRespuesta, @cMensaje cMensaje, @IDAutoriza nIdAutoriza--01/08/2023 DHFI Se comenta
									SELECT RIGHT('0' + CAST(@nResult AS VARCHAR(2)),2) cRespuesta, @cMensaje cMensaje, @IDAutoriza nIdAutoriza,@cNomEntidad cNomEntidad, @cNombreClienteDestino cNombreAp, @cCtaCodOrigen cCtaCodOrigen----01/08/2023 DHFI Se agrega entidad y nombre
									ROLLBACK TRAN TR_Transferencia_OffHost
									--EVENTOS
									INSERT INTO AppEventos VALUES (0,@cAppTipoTransferencia,'Transferencia', GETDATE(),@ldFechaSistema,@cCtaCodOrigen,@cCtaCodDestino,@nResult,@cMensaje)
									SET @cMensaje = 'Ocurrió un error durante la transacción.' --24/12/2019 LVCH --se optimia mensaje
									--EVENTOS
								END	CATCH
							END -- PMRS YYYY/MM/DD Fin lógica offhost
						END				
						ELSE
						BEGIN
							SET  @IDAutoriza = 0
							IF @nResult not in (82,83,84,85)
								SELECT @cMensaje = cDescError FROM CodigosError WITH(NOLOCK) WHERE cCodError = @nResult

							--SELECT RIGHT('0' + CAST(@nResult AS VARCHAR(2)),2) cRespuesta, @cMensaje cMensaje, @IDAutoriza nIdAutoriza--01/08/2023 DHFI Se comenta
							SELECT RIGHT('0' + CAST(@nResult AS VARCHAR(2)),2) cRespuesta, @cMensaje cMensaje, @IDAutoriza nIdAutoriza,@cNomEntidad cNomEntidad, @cNombreClienteDestino cNombreAp, @cCtaCodOrigen cCtaCodOrigen----01/08/2023 DHFI Se agrega entidad y nombre
							
							--EVENTOS
							INSERT INTO AppEventos VALUES (0,@cAppTipoTransferencia,'Transferencia', GETDATE(),@ldFechaSistema,@cCtaCodOrigen,@cCtaCodDestino,@nResult,@cMensaje)
							--EVENTOS
						END	
						
				END TRY
			
				BEGIN CATCH
					
					IF @nResult = -1
						SET @nResult = 12
					SET @IDAutoriza = 0
					SET @cMensaje = ERROR_MESSAGE()				
					--EVENTOS
					INSERT INTO AppEventos VALUES (0,@cAppTipoTransferencia,'Transferencia', GETDATE(),@ldFechaSistema,@cCtaCodOrigen,@cCtaCodDestino,@nResult,@cMensaje)
					SET @cMensaje = 'Ocurrió un error durante la transacción.' 
					--EVENTOS
					--SELECT RIGHT('0' + CAST(@nResult AS VARCHAR(2)),2) cRespuesta, @cMensaje cMensaje, @IDAutoriza nIdAutoriza--01/08/2023 DHFI Se comenta
					SELECT RIGHT('0' + CAST(@nResult AS VARCHAR(2)),2) cRespuesta, @cMensaje cMensaje, @IDAutoriza nIdAutoriza,@cNomEntidad cNomEntidad, '' cNombreAp, '' cCtaCodOrigen----01/08/2023 DHFI Se agrega entidad y nombre
					
				END CATCH
			END
			-- ELSE
			-- BEGIN
			-- 	SET @nResult = 90 --NO PERTENECE A PILOTO
			-- 	SET @IDAutoriza = 0 --NO PERTENECE A PILOTO
			-- 	SET @cMensaje = 'No pertence a piloto'
			-- 	--SELECT RIGHT('0' + CAST(@nResult AS VARCHAR(2)),2) cRespuesta, @cMensaje cMensaje, @IDAutoriza nIdAutoriza--01/08/2023 DHFI Se comenta
			-- 	SELECT RIGHT('0' + CAST(@nResult AS VARCHAR(2)),2) cRespuesta, @cMensaje cMensaje, @IDAutoriza nIdAutoriza,@cNomEntidad cNomEntidad, '' cNombreAp, '' cCtaCodOrigen----01/08/2023 DHFI Se agrega entidad y nombre
			-- END
		-- END -- PMRS YYYY/MM/DD Se mueve logica de offhost luego de las validaciones
		-- ELSE
		-- BEGIN
		-- 	SET @nResult = 97 --NO PERTENECE A PILOTO
		-- 	SET @IDAutoriza = 0 --NO PERTENECE A PILOTO
		-- 	SET @cMensaje = 'En este momento no podemos realizar su transacción.'
		-- 	--SELECT RIGHT('0' + CAST(@nResult AS VARCHAR(2)),2) cRespuesta, @cMensaje cMensaje, @IDAutoriza nIdAutoriza--01/08/2023 DHFI Se comenta
		-- 	SELECT RIGHT('0' + CAST(@nResult AS VARCHAR(2)),2) cRespuesta, @cMensaje cMensaje, @IDAutoriza nIdAutoriza,@cNomEntidad cNomEntidad, '' cNombreAp, '' cCtaCodOrigen----01/08/2023 DHFI Se agrega entidad y nombre
		-- END		
	SET NOCOUNT OFF	
END
GO


