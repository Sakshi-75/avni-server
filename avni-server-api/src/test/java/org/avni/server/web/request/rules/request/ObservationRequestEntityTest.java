package org.avni.server.web.request.rules.request;

import org.junit.Test;
import static org.junit.Assert.*;

public class ObservationRequestEntityTest {
    @Test
    public void testGettersAndSetters() {
        ObservationRequestEntity entity = new ObservationRequestEntity();
        
        entity.setConceptUUID("uuid");
        assertEquals("uuid", entity.getConceptUUID());
        
        entity.setValue("value");
        assertEquals("value", entity.getValue());
    }
}
