package org.avni.server.builder;

import org.junit.Test;

import static org.junit.Assert.*;

public class BuilderExceptionTest {
    @Test
    public void testBuilderExceptionWithMessage() {
        BuilderException exception = new BuilderException("Error message");
        assertEquals("Error message", exception.getMessage());
        assertEquals("Error message", exception.getUserMessage());
    }
    
    @Test
    public void testBuilderExceptionWithBundleMessage() {
        BuilderException exception = new BuilderException("Error", "Bundle info");
        assertEquals("Error (Bundle info)", exception.getMessage());
        assertEquals("Error", exception.getUserMessage());
    }
}
