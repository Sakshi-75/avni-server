package org.avni.server.exporter.v2;

import org.avni.server.dao.ExportJobParametersRepository;
import org.avni.server.domain.*;
import org.avni.server.web.external.request.export.ExportOutput;
import org.avni.server.web.external.request.export.ExportEntityType;
import org.joda.time.DateTime;
import org.junit.Before;
import org.junit.Test;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;

import java.util.*;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

public class ExportV2ProcessorTest {
    @Mock private ExportJobParametersRepository exportJobParametersRepository;
    
    private ExportV2Processor processor;
    
    @Before
    public void setUp() {
        MockitoAnnotations.initMocks(this);
        processor = new ExportV2Processor(exportJobParametersRepository, "uuid1");
        
        ExportJobParameters params = new ExportJobParameters();
        params.setTimezone("Asia/Calcutta");
        when(exportJobParametersRepository.findByUuid("uuid1")).thenReturn(params);
        
        processor.init();
        processor.setExportOutput(new ExportOutput());
    }
    
    @Test
    public void testProcessIndividual() {
        Individual individual = new Individual();
        individual.setUuid("ind-uuid");
        
        LongitudinalExportItemRow result = processor.process(individual);
        
        assertNotNull(result);
        assertEquals(individual, result.getIndividual());
    }
    
    @Test
    public void testProcessIndividualWithNullCollections() {
        Individual individual = new Individual();
        individual.setUuid("ind-uuid");
        individual.setEncounters(null);
        individual.setProgramEnrolments(null);
        
        LongitudinalExportItemRow result = processor.process(individual);
        
        assertNotNull(result);
        assertEquals(individual, result.getIndividual());
    }
    
    @Test
    public void testApplyFiltersWithNullEntity() {
        Map<String, ExportEntityType> map = new HashMap<>();
        
        boolean result = processor.applyFilters(map, "uuid1", DateTime.now(), false);
        
        assertFalse(result);
    }
    
    @Test
    public void testApplyFiltersWithEntity() {
        Map<String, ExportEntityType> map = new HashMap<>();
        ExportEntityType entity = new ExportEntityType();
        entity.setUuid("uuid1");
        map.put("uuid1", entity);
        
        boolean result = processor.applyFilters(map, "uuid1", DateTime.now(), false);
        
        assertTrue(result);
    }
}
