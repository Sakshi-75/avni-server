package org.avni.server.util;

import org.junit.Test;
import static org.junit.Assert.*;

public class BadRequestErrorTest {
    @Test
    public void testExceptionMessage() {
        BadRequestError error = new BadRequestError("Test error");
        assertEquals("Test error", error.getMessage());
    }
    
    @Test
    public void testExceptionWithFormatting() {
        BadRequestError error = new BadRequestError("Error: %s, Code: %d", "Invalid input", 400);
        assertEquals("Error: Invalid input, Code: 400", error.getMessage());
    }
    
    @Test
    public void testExceptionIsRuntimeException() {
        BadRequestError error = new BadRequestError("Test");
        assertTrue(error instanceof RuntimeException);
    }
}
