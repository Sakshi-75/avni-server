package org.avni.server.util;

import org.junit.Test;

import static org.junit.Assert.*;

public class BooleanUtilTest {
    @Test
    public void testGetBooleanWithNull() {
        assertTrue(BooleanUtil.getBoolean(null, true));
        assertFalse(BooleanUtil.getBoolean(null, false));
    }
    
    @Test
    public void testGetBooleanWithValue() {
        assertTrue(BooleanUtil.getBoolean(true, false));
        assertFalse(BooleanUtil.getBoolean(false, true));
    }
}
