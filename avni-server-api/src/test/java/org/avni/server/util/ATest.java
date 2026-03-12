package org.avni.server.util;

import org.junit.Test;

import static org.junit.Assert.*;

public class ATest {
    @Test
    public void testFindIndicesOf() {
        String[] array = {"a", "b", "c", "b"};
        int[] result = A.findIndicesOf(array, "b");
        assertEquals(2, result.length);
        assertEquals(1, result[0]);
        assertEquals(3, result[1]);
    }
    
    @Test
    public void testReplaceEntriesAtIndicesWith() {
        String[] array = {"a", "b", "c", "d"};
        int[] indices = {1, 3};
        A.replaceEntriesAtIndicesWith(array, indices, "x");
        assertEquals("x", array[1]);
        assertEquals("x", array[3]);
        assertEquals("a", array[0]);
    }
}
