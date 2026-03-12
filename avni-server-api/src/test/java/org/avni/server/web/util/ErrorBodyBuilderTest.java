package org.avni.server.web.util;

import org.junit.Test;
import static org.junit.Assert.*;

public class ErrorBodyBuilderTest {
    @Test
    public void testGetErrorBodyWithException() {
        ErrorBodyBuilder builder = ErrorBodyBuilder.createForTest();
        Exception e = new RuntimeException("test error");
        String result = builder.getErrorBody(e);
        assertTrue(result.contains("test error"));
    }
    
    @Test
    public void testGetErrorBodyWithString() {
        ErrorBodyBuilder builder = ErrorBodyBuilder.createForTest();
        String result = builder.getErrorBody("error message");
        assertEquals("error message", result);
    }
    
    @Test
    public void testGetErrorMessageBody() {
        ErrorBodyBuilder builder = ErrorBodyBuilder.createForTest();
        Throwable t = new Throwable("throwable message");
        String result = builder.getErrorMessageBody(t);
        assertEquals("throwable message", result);
    }
}
