package cmaccusco.rpando.dbtests;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;

import java.sql.Connection;
import java.sql.SQLException;

public abstract class BaseDBTest {
    private static HikariDataSource dataSource;
    protected Connection conn;

    @BeforeAll
    static void initDataSource() {
        String jdbcUrl = "jdbc:sqlserver://svrdesasql01;databaseName=DBTarjeta;encrypt=false;trustServerCertificate=true;";
        String username = "userUBA";
        String password = "Ub@nc@us3r#2";

        HikariConfig config = new HikariConfig();
        config.setJdbcUrl(jdbcUrl);
        config.setUsername(username);
        config.setPassword(password);

        // Deshabilitar auto commit globalmente para forzar seguridad transaccional en las pruebas
        config.setAutoCommit(false);
        config.setMaximumPoolSize(5);

        dataSource = new HikariDataSource(config);
    }

    @BeforeEach
    void openConnectionForEachTest() throws SQLException {
        this.conn = dataSource.getConnection();
        this.conn.setAutoCommit(false);
    }

    @AfterEach
    void rollbackAndCloseForEachTest() {
        if (this.conn != null) {
            try {
                this.conn.rollback();
            } catch (SQLException e) {
                System.err.println("Error al hacer rollback");
            } finally {
                try {
                    this.conn.close();
                } catch (SQLException e) {
                    System.err.println("Error cerrando la conexión");
                }
            }
        }
    }

    @AfterAll
    static void closeDataSource() {
        if (dataSource != null) {
            dataSource.close();
        }
    }
}
