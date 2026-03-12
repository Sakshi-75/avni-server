package org.avni.server.web.request;

import org.junit.Test;
import static org.junit.Assert.*;

public class ExportRequestTest {
    @Test
    public void testGettersAndSetters() {
        ExportRequest request = new ExportRequest();
        assertNull(request.getFileName());
        
        request.setFileName("export.csv");
        assertEquals("export.csv", request.getFileName());
    }
}
