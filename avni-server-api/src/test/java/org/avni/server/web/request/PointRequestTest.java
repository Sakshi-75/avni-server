package org.avni.server.web.request;

import org.junit.Test;
import static org.junit.Assert.*;

public class PointRequestTest {
    @Test
    public void testGettersAndSetters() {
        PointRequest request = new PointRequest();
        assertEquals(0.0, request.getX(), 0.001);
        assertEquals(0.0, request.getY(), 0.001);
        
        request.setX(12.34);
        request.setY(56.78);
        
        assertEquals(12.34, request.getX(), 0.001);
        assertEquals(56.78, request.getY(), 0.001);
    }
}
