package cmaccusco.rpando.dbtests;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.assertEquals;

import java.sql.SQLException;

public class TestSuma extends BaseDBTest {
    @Test
    void test_TestSencillo() throws SQLException {
        // -- ARRANGE
        Integer numero1 = 10 + 2;
        Integer numero2 = 20;
        // -- ACT
        Integer suma = numero1 + numero2;
        // -- ASSERT
        assertEquals(32, suma);
    }
}
