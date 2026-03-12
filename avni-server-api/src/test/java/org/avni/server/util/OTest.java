package org.avni.server.util;

import org.junit.Test;
import java.util.Date;
import static org.junit.Assert.*;

public class OTest {
    @Test
    public void testGetFullPath() {
        String path = O.getFullPath("test");
        assertTrue(path.startsWith("file:///"));
        assertTrue(path.endsWith("/"));
    }
    
    @Test
    public void testGetDateInDbFormat() {
        Date date = new Date(1678886400000L); // 2023-03-15
        String formatted = O.getDateInDbFormat(date);
        assertNotNull(formatted);
        assertTrue(formatted.matches("\\d{4}-\\d{2}-\\d{2}"));
    }
    
    @Test
    public void testGetDateFromDbFormat() {
        Date date = O.getDateFromDbFormat("2023-03-15");
        assertNotNull(date);
    }
    
    @Test
    public void testCoalesceReturnsFirstNonNull() {
        assertEquals("first", O.coalesce("first", "second"));
        assertEquals("second", O.coalesce(null, "second"));
        assertEquals("third", O.coalesce(null, null, "third"));
    }
    
    @Test
    public void testCoalesceReturnsNullWhenAllNull() {
        assertNull(O.coalesce(null, null, null));
    }
}
