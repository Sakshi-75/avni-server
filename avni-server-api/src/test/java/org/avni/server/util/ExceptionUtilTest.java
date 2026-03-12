package org.avni.server.util;

import org.junit.Test;

import static org.junit.Assert.*;

public class ExceptionUtilTest {
    @Test
    public void testGetFullStackTrace() {
        Exception e = new Exception("test error");
        String result = ExceptionUtil.getFullStackTrace(e);
        assertNotNull(result);
        assertTrue(result.contains("test error"));
        assertTrue(result.contains("Exception"));
    }
}
