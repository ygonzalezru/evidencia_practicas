
BEGIN
    IF :NEW.id_talento IS NULL THEN
        SELECT seq_talento.NEXTVAL INTO :NEW.id_talento FROM dual;
    END IF;
END;
/
--- CREACION TABLA DE LA CUENTA DE COBRO
---CREACIÓN DE LA SECUENCIA PARA CUENTA DE COBRO
CREATE SEQUENCE seq_cuenta_cobro START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
--CREACION DE LA RABLA DE LA CUENTA DE COBRO
CREATE TABLE cuenta_cobro (
    id_cuenta         NUMBER PRIMARY KEY,
    id_talento        NUMBER NOT NULL,
    fecha_radicacion  DATE DEFAULT SYSDATE,
    tipo_contenido    VARCHAR2(50),
    valor_contenido   NUMBER(12,2),
    valor_total       NUMBER(12,2) DEFAULT 0,
    estado            VARCHAR2(20) DEFAULT 'PENDIENTE',
    CONSTRAINT fk_cuenta_talento FOREIGN KEY (id_talento) REFERENCES talento(id_talento),
    CONSTRAINT ck_tipo_contenido_cb CHECK (tipo_contenido IS NULL OR tipo_contenido IN ('REEL','REEL_COMPARTIDO','HISTORIA','HISTORIA_COMPARTIDA','LIVE')),
    CONSTRAINT ck_valores_maximos_cb CHECK (
        tipo_contenido IS NULL OR
        (tipo_contenido = 'REEL' AND valor_contenido <= 200000) OR
        (tipo_contenido = 'REEL_COMPARTIDO' AND valor_contenido <= 150000) OR
        (tipo_contenido = 'HISTORIA' AND valor_contenido <= 50000) OR
        (tipo_contenido = 'HISTORIA_COMPARTIDA' AND valor_contenido <= 30000) OR
        (tipo_contenido = 'LIVE' AND valor_contenido <= 350000)
    )
);

---CREACION DE TRIGGER PARA LA CUENTA DE COBRO Y DEL ID DE LA CUENTA
CREATE OR REPLACE TRIGGER trg_cuenta_cobro_pk
BEFORE INSERT ON cuenta_cobro
FOR EACH ROW
BEGIN
    IF :NEW.id_cuenta IS NULL THEN
        SELECT seq_cuenta_cobro.NEXTVAL INTO :NEW.id_cuenta FROM dual;
    END IF;
END;
/

---CREACIÓN DE CONTENIDO
--- CREACIÓN DE SECUENCIA PARA CONTENIDO
CREATE SEQUENCE seq_contenido START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
---CREACION DE TABLA DE CONTENIDO
CREATE TABLE contenido (
    id_contenido      NUMBER PRIMARY KEY,
    id_cuenta         NUMBER NOT NULL,
    tipo_contenido    VARCHAR2(50) NOT NULL,
    valor_contenido   NUMBER(12,2) NOT NULL,
    CONSTRAINT fk_contenido_cuenta FOREIGN KEY (id_cuenta) REFERENCES cuenta_cobro(id_cuenta) ON DELETE CASCADE,
    CONSTRAINT ck_tipo_contenido CHECK (tipo_contenido IN ('REEL','REEL_COMPARTIDO','HISTORIA','HISTORIA_COMPARTIDA','LIVE')),
    CONSTRAINT ck_valores_maximos CHECK (
        (tipo_contenido = 'REEL' AND valor_contenido <= 200000) OR
        (tipo_contenido = 'REEL_COMPARTIDO' AND valor_contenido <= 150000) OR
        (tipo_contenido = 'HISTORIA' AND valor_contenido <= 50000) OR
        (tipo_contenido = 'HISTORIA_COMPARTIDA' AND valor_contenido <= 30000) OR
        (tipo_contenido = 'LIVE' AND valor_contenido <= 350000)
    )
);
---CREACION DE TRIGGER
CREATE OR REPLACE TRIGGER trg_contenido_pk
BEFORE INSERT ON contenido
FOR EACH ROW
BEGIN
    IF :NEW.id_contenido IS NULL THEN
        SELECT seq_contenido.NEXTVAL INTO :NEW.id_contenido FROM dual;
    END IF;
END;
/
-----ORDEN DE PRODUCCIÓN O LA LLAMADA "OP"
--CREACIÓN DE SECUENCIA
CREATE SEQUENCE seq_orden_produccion START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE TABLE orden_produccion (
    id_orden          NUMBER PRIMARY KEY,
    id_cuenta         NUMBER NOT NULL,
    descripcion       VARCHAR2(200),
    fecha_entrega     DATE,
    valor_unitario    NUMBER(12,2),
    CONSTRAINT fk_orden_cuenta FOREIGN KEY (id_cuenta) REFERENCES cuenta_cobro(id_cuenta)
);

CREATE OR REPLACE TRIGGER trg_orden_produccion_pk
BEFORE INSERT ON orden_produccion
FOR EACH ROW
BEGIN
    IF :NEW.id_orden IS NULL THEN
        SELECT seq_orden_produccion.NEXTVAL INTO :NEW.id_orden FROM dual;
    END IF;
END;
/
------CREACIÓN DE PRODUCCIÓN
------CREACIÓN DE SECUENCIA
CREATE SEQUENCE seq_aprobacion START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
------
CREATE TABLE aprobacion (
    id_aprobacion     NUMBER PRIMARY KEY,
    id_cuenta         NUMBER NOT NULL,
    id_usuario_aprueba VARCHAR2(50),
    fecha_aprobacion  DATE DEFAULT SYSDATE,
    estado_aprobacion VARCHAR2(20) DEFAULT 'PENDIENTE',
    observaciones     VARCHAR2(200),
    CONSTRAINT fk_aprobacion_cuenta FOREIGN KEY (id_cuenta) REFERENCES cuenta_cobro(id_cuenta)
);
----------CREACION DE TRIGGER
CREATE OR REPLACE TRIGGER trg_aprobacion_pk
BEFORE INSERT ON aprobacion
FOR EACH ROW
BEGIN
    IF :NEW.id_aprobacion IS NULL THEN
        SELECT seq_aprobacion.NEXTVAL INTO :NEW.id_aprobacion FROM dual;
    END IF;
END;
/

----------creación de trigger de cambios de cuenta de cobro
-- SECUENCIA para BITACORA_CUENTA_COBRO
CREATE SEQUENCE seq_bitacora_cuenta_cobro
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;

-- TABLA BITACORA_CUENTA_COBRO
CREATE TABLE bitacora_cuenta_cobro (
    id_log           NUMBER PRIMARY KEY,
    id_cuenta        NUMBER NOT NULL,
    estado_anterior  VARCHAR2(20),
    estado_nuevo     VARCHAR2(20),
    usuario          VARCHAR2(50),
    fecha_operacion  DATE DEFAULT SYSDATE,
    observaciones    VARCHAR2(200),
    CONSTRAINT fk_bitacora_cuenta FOREIGN KEY (id_cuenta) REFERENCES cuenta_cobro(id_cuenta)
);

-- TRIGGER DE AUDITORÍA DE CAMBIO DE ESTADO
CREATE OR REPLACE TRIGGER trg_auditoria_estado_cuenta
AFTER UPDATE OF estado ON cuenta_cobro
FOR EACH ROW
BEGIN
    IF :OLD.estado != :NEW.estado THEN
        INSERT INTO bitacora_cuenta_cobro(
            id_log,
            id_cuenta,
            estado_anterior,
            estado_nuevo,
            usuario,
            observaciones
        )
        VALUES (
            seq_bitacora_cuenta_cobro.NEXTVAL,
            :NEW.id_cuenta,
            :OLD.estado,
            :NEW.estado,
            USER,
            'Cambio de estado en cuenta de cobro'
        );
    END IF;
END;
/

INSERT INTO cuenta_cobro(id_talento, tipo_contenido, valor_contenido, valor_total)
VALUES (1, 'REEL', 180000, 180000);

INSERT INTO contenido(id_cuenta, tipo_contenido, valor_contenido) VALUES (1, 'REEL', 180000);
INSERT INTO contenido(id_cuenta, tipo_contenido, valor_contenido) VALUES (1, 'HISTORIA', 50000);

INSERT INTO orden_produccion(id_cuenta, descripcion, fecha_entrega, valor_unitario)
VALUES (1, 'Producción de cuña radial', SYSDATE+7, 80000);

INSERT INTO aprobacion(id_cuenta, id_usuario_aprueba, estado_aprobacion, observaciones)
VALUES (1, 'admin', 'APROBADO', 'Cumple con los requisitos');

COMMIT;

-------PRUEBA DE TRIGGER DE ESTADO DE LA CUENTA DE COBRO
UPDATE cuenta_cobro
SET estado = 'APROBADO'
WHERE id_cuenta = 1;

COMMIT;

-- Consultar la bitácora
SELECT * FROM bitacora_cuenta_cobro;


SELECT * FROM DBA_BLOCKERS;

SELECT * FROM DBA_WAITERS;

---creacion de tabla de registro de bloqueos ya resueltos
-- Secuencia para ID
CREATE SEQUENCE seq_registro_bloqueos
START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- Tabla para almacenar bloqueos detectados
CREATE TABLE registro_bloqueos (
    id_bloqueo       NUMBER PRIMARY KEY,
    sid_sesion       NUMBER NOT NULL,
    serial_sesion    NUMBER NOT NULL,
    usuario          VARCHAR2(50),
    objeto_afectado  VARCHAR2(100),
    fecha_registro   DATE DEFAULT SYSDATE,
    accion_tomada    VARCHAR2(100)
);

--CREACIÓN DE PROCEDIMIENTO DE ALMACENADOS


CREATE OR REPLACE PROCEDURE resolver_bloqueos AS
BEGIN
    FOR bloqueo IN (
        SELECT s.sid, s.serial#, s.username, o.object_name
        FROM v$lock l
        JOIN v$session s ON l.sid = s.sid
        LEFT JOIN dba_objects o ON l.id1 = o.object_id
        WHERE s.username IS NOT NULL
        AND l.block > 0 -- sesiones que bloquean
    )
    LOOP
        -- Registrar el bloqueo
        INSERT INTO registro_bloqueos (
            id_bloqueo, sid_sesion, serial_sesion, usuario, objeto_afectado, accion_tomada
        ) VALUES (
            seq_registro_bloqueos.NEXTVAL,
            bloqueo.sid,
            bloqueo.serial#,             
            bloqueo.username,
            bloqueo.object_name,
            'Sesion finalizada por bloqueo'
        );

        -- Terminar la sesión para liberar el bloqueo
        EXECUTE IMMEDIATE 'ALTER SYSTEM KILL SESSION ''' || bloqueo.sid || ',' || bloqueo.serial# || ''' IMMEDIATE';
    END LOOP;

    COMMIT;
END;
/

GRANT SELECT ON V_$LOCK TO sistema_emisora;
GRANT SELECT ON V_$SESSION TO sistema_emisora;
GRANT SELECT ON DBA_OBJECTS TO sistema_emisora;
GRANT SELECT ON V_$LOCKED_OBJECT TO sistema_emisora;
GRANT SELECT ON DBA_BLOCKERS TO sistema_emisora;
GRANT SELECT ON DBA_WAITERS TO sistema_emisora;

----creación job (tareas automaticas)
BEGIN
    DBMS_SCHEDULER.create_job (
        job_name        => 'JOB_RESOLVER_BLOQUEOS',
        job_type        => 'STORED_PROCEDURE',
        job_action      => 'resolver_bloqueos',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=MINUTELY; INTERVAL=60',
        enabled         => TRUE
    );
END;
/



